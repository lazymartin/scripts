import os
import re
import sys
import argparse
import urllib.request
from datetime import datetime
from collections import defaultdict

try:
    import geoip2.database
    from geoip2.errors import AddressNotFoundError
except ImportError:
    print("错误: 缺少本地离线数据库解析库 'geoip2'。")
    print("请先在终端执行命令安装: pip3 install geoip2 (或 apt install python3-geoip2)")
    exit(1)

# 全局内存缓存
ip_geo_cache = {}


def report_progress(block_num, block_size, total_size):
    """下载进度条回调函数"""
    downloaded = block_num * block_size
    if total_size > 0:
        percent = min(downloaded * 100 / total_size, 100.0)
        sys.stdout.write(f"\r      进度: {percent:.1f}% ({downloaded / (1024 * 1024):.2f} MB / {total_size / (1024 * 1024):.2f} MB)")
    else:
        sys.stdout.write(f"\r      已下载: {downloaded / (1024 * 1024):.2f} MB")
    sys.stdout.flush()


# 默认路径配置
DEFAULT_DB_DIR = "/usr/local/share/xray/"


def check_and_download_dbs(city_path, asn_path):
    """检查数据库文件是否存在，若不存在则提示下载"""
    db_dir = os.path.dirname(city_path)
    if not os.path.exists(db_dir):
        try:
            os.makedirs(db_dir, exist_ok=True)
            print(f"[+] 已创建目录: {db_dir}")
        except PermissionError:
            print(f"[-] 错误: 无权限创建目录 {db_dir}，请尝试使用 sudo 运行。")
            return False

    missing = []
    db_urls = {
        city_path: "https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb",
        asn_path: "https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb"
    }

    if not os.path.exists(city_path):
        missing.append(city_path)
    if not os.path.exists(asn_path):
        missing.append(asn_path)

    if not missing:
        return True

    print("\n[!] 缺少离线 IP 数据库文件:")
    for db in missing:
        print(f"    - {db}")

    choice = input(f"\n是否立即从 GitHub 自动下载到 {db_dir}? [y/N]: ").strip().lower()
    if choice in ['y', 'yes']:
        opener = urllib.request.build_opener()
        opener.addheaders = [('User-Agent', 'Mozilla/5.0')]
        urllib.request.install_opener(opener)
        for db in missing:
            print(f"  >>> 正在下载: {os.path.basename(db)}")
            try:
                urllib.request.urlretrieve(db_urls[db], db, reporthook=report_progress)
                print(f"\n  ✅ 下载完成: {db}")
            except Exception as e:
                print(f"\n  ❌ 下载失败 ({db}): {e}")
        return True
    return False


def get_combined_ip_info(ip, city_reader, asn_reader):
    """同时查询 City 和 ASN 数据库，并合并结果"""
    query_ip = ip.replace('*', '1')

    if query_ip.startswith(('10.', '192.168.', '172.')) or query_ip == '127.0.0.1':
        return "局域网/保留地址"

    if query_ip in ip_geo_cache:
        return ip_geo_cache[query_ip]

    location_str, asn_str = "", ""

    if city_reader:
        try:
            response = city_reader.city(query_ip)
            country = response.country.names.get('zh-CN', response.country.name) or ''
            region = response.subdivisions.most_specific.names.get('zh-CN', response.subdivisions.most_specific.name) or ''
            city = response.city.names.get('zh-CN', response.city.name) or ''

            parts = [part for part in (country, region, city) if part]
            location_str = " ".join(parts).replace(f"{region} {region}", region)
        except AddressNotFoundError:
            pass
        except Exception:
            location_str = "城市解析出错"

    if asn_reader:
        try:
            response = asn_reader.asn(query_ip)
            asn_str = f"AS{response.autonomous_system_number} {response.autonomous_system_organization}"
        except AddressNotFoundError:
            pass
        except Exception:
            asn_str = "ASN解析出错"

    if not location_str and not asn_str:
        final_result = "数据库中无此IP记录"
    else:
        final_result = f"{location_str} ({asn_str})".strip()
        if final_result.startswith('()'):
            final_result = final_result.replace('()', '').strip()

    ip_geo_cache[query_ip] = final_result
    return final_result


def analyze_xray_logs(log_file_path, city_db_path, asn_db_path, time_window_seconds=60, interval='today', target_users=None):
    """
    分析 Xray 日志中的多设备并发行为
    
    Args:
        target_users: 指定要分析的用户名列表(email)，为 None 或空列表时分析全部用户
    """
    # 检查并尝试下载数据库
    check_and_download_dbs(city_db_path, asn_db_path)

    city_reader, asn_reader = None, None

    try:
        city_reader = geoip2.database.Reader(city_db_path)
    except FileNotFoundError:
        print(f"[-] 警告: 未找到 City 数据库，跳过城市解析。")

    try:
        asn_reader = geoip2.database.Reader(asn_db_path)
    except FileNotFoundError:
        print(f"[-] 警告: 未找到 ASN 数据库，跳过运营商解析。")

    if not city_reader and not asn_reader:
        print("错误: 必须至少提供一个有效的离线数据库文件才能运行分析！")
        return

    log_pattern = re.compile(
        r"^(\d{4}/\d{2}/\d{2}\s\d{2}:\d{2}:\d{2}).*?(?:from\s+)?(?:tcp:|udp:)?([0-9\.\*]+|\[[a-fA-F0-9:]+\]):\d+\s+accepted.*?email:\s+(\S+)"
    )

    user_activity = defaultdict(list)
    system_today = datetime.now().date()

    # 预处理目标用户集合，提升查找效率
    user_filter = set(target_users) if target_users else None

    try:
        with open(log_file_path, 'r', encoding='utf-8') as f:
            for line in f:
                match = log_pattern.search(line)
                if match:
                    time_str, ip, user = match.groups()

                    # ★ 核心过滤：如果指定了用户，仅保留匹配的记录
                    if user_filter and user not in user_filter:
                        continue

                    timestamp = datetime.strptime(time_str, "%Y/%m/%d %H:%M:%S")

                    if interval == 'today' and timestamp.date() != system_today:
                        continue
                    user_activity[user].append({"time": timestamp, "ip": ip})
    except FileNotFoundError:
        print(f"错误: 找不到日志文件 {log_file_path}")
        if city_reader:
            city_reader.close()
        if asn_reader:
            asn_reader.close()
        return

    # 检查过滤后是否有数据
    if user_filter and not user_activity:
        print(f"\n[!] 在日志中未找到以下指定用户的任何记录: {', '.join(sorted(user_filter))}")
        print("    请检查用户名是否正确，或调整 --interval 参数扩大时间范围。")
        if city_reader:
            city_reader.close()
        if asn_reader:
            asn_reader.close()
        return

    def get_bucket_key(ts):
        if interval == 'monthly':
            return ts.strftime("%Y年%m月")
        elif interval == 'weekly':
            return ts.strftime("%Y年第%W周")
        else:
            return ts.strftime("%Y/%m/%d")

    stats = defaultdict(lambda: defaultdict(lambda: {'event_count': 0, 'involved_ips': set()}))

    for user, activities in user_activity.items():
        activities.sort(key=lambda x: x['time'])
        reported_windows = set()

        for i in range(len(activities)):
            current = activities[i]
            active_ips = {current['ip']}

            for j in range(i + 1, len(activities)):
                compare = activities[j]
                if (compare['time'] - current['time']).total_seconds() <= time_window_seconds:
                    active_ips.add(compare['ip'])
                else:
                    break

            if len(active_ips) > 1:
                time_marker = current['time'].strftime("%Y/%m/%d %H:%M")
                overlap_key = f"{time_marker}-{'-'.join(sorted(list(active_ips)))}"

                if overlap_key not in reported_windows:
                    bucket = get_bucket_key(current['time'])
                    stats[bucket][user]['event_count'] += 1
                    stats[bucket][user]['involved_ips'].update(active_ips)
                    reported_windows.add(overlap_key)

    # 构建输出标题
    filter_desc = ""
    if user_filter:
        filter_desc = f" | 指定用户: {', '.join(sorted(user_filter))}"

    print(f"\n========== 代理日志并发统计 (按 {interval} 聚合 - 本地双库解析{filter_desc}) ==========")
    print(f"日志文件: {log_file_path} | 并发窗口: {time_window_seconds}秒")

    if not stats:
        if interval == 'today':
            print(f"\n未发现今天 ({system_today.strftime('%Y/%m/%d')}) 有任何多设备并发记录。")
        else:
            print("\n未发现任何多设备并发/IP交替使用的记录。")
        print("======================================================================")
    else:
        for period, users in sorted(stats.items()):
            print(f"\n【时间】 {period}")
            for user, stat in users.items():
                print(f"  -> 账号: [{user}]")
                print(f"     并发交替次数: {stat['event_count']} 次 (基于 {time_window_seconds} 秒窗口)")
                print(f"     期间涉及源IP及位置:")

                for ip in sorted(list(stat['involved_ips'])):
                    location = get_combined_ip_info(ip, city_reader, asn_reader)
                    print(f"       - {ip:<15} [{location}]")

                if stat['event_count'] > 5:
                    print("     [!] 评估: 频次较高，极大概率为多设备同时重度使用。")
                else:
                    print("     [-] 评估: 频次较低，可能为单设备网络切换。")

        print("\n======================================================================")

    if city_reader:
        city_reader.close()
    if asn_reader:
        asn_reader.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Xray 并发分析工具", formatter_class=argparse.RawTextHelpFormatter)

    parser.add_argument("-f", "--file", default="/var/log/xray/access.log",
                        help=f"日志文件路径 (默认: /var/log/xray/access.log)")
    parser.add_argument("--city", default=os.path.join(DEFAULT_DB_DIR, "GeoLite2-City.mmdb"),
                        help=f"City 数据库路径 (默认: {DEFAULT_DB_DIR}GeoLite2-City.mmdb)")
    parser.add_argument("--asn", default=os.path.join(DEFAULT_DB_DIR, "GeoLite2-ASN.mmdb"),
                        help=f"ASN 数据库路径 (默认: {DEFAULT_DB_DIR}GeoLite2-ASN.mmdb)")
    parser.add_argument("-i", "--interval", choices=['today', 'weekly', 'monthly'], default='today',
                        help=f"统计维度: 当天/本周/本月 (默认: today)")
    parser.add_argument("-w", "--window", type=int, default=60,
                        help=f"重叠判定窗口/秒 (默认: 60)")
    parser.add_argument("-u", "--user", nargs='+', metavar='EMAIL',
                        help="指定要分析的用户名(email)，支持多个\n"
                             "示例: -u user1@example.com user2@example.com\n"
                             "不指定时分析全部用户")

    args = parser.parse_args()
    analyze_xray_logs(
        args.file,
        args.city,
        args.asn,
        time_window_seconds=args.window,
        interval=args.interval,
        target_users=args.user
    )

