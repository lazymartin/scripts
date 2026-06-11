import os
import re
import sys
import argparse
import urllib.request
from datetime import datetime
from collections import defaultdict

# ... (geoip2 导入部分保持不变) ...

# 默认路径配置
DEFAULT_DB_DIR = "/usr/local/share/xray/"

def check_and_download_dbs(city_path, asn_path):
    """检查数据库文件是否存在，若不存在则提示下载"""
    # 自动创建目录
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

    if not os.path.exists(city_path): missing.append(city_path)
    if not os.path.exists(asn_path): missing.append(asn_path)

    if not missing: return True

    print("\n[!] 缺少离线 IP 数据库文件:")
    for db in missing: print(f"    - {db}")
    
    choice = input(f"\n是否立即从 GitHub 自动下载到 {db_dir}? [y/N]: ").strip().lower()
    if choice in ['y', 'yes']:
        opener = urllib.request.build_opener()
        opener.addheaders = [('User-Agent', 'Mozilla/5.0')]
        urllib.request.install_opener(opener)
        for db in missing:
            print(f"  >>> 正在下载: {os.path.basename(db)}")
            try:
                urllib.request.urlretrieve(db_urls[db], db)
                print(f"  ✅ 下载完成: {db}")
            except Exception as e:
                print(f"  ❌ 下载失败 ({db}): {e}")
        return True
    return False

# ... (后续分析逻辑保持不变，只需在 argparse 中更新默认值) ...

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Xray 并发分析工具", formatter_class=argparse.RawTextHelpFormatter)
    
    parser.add_argument("-f", "--file", default="xray.log", help="日志文件路径")
    parser.add_argument("--city", default=os.path.join(DEFAULT_DB_DIR, "GeoLite2-City.mmdb"), help=f"City 数据库路径 (默认: {DEFAULT_DB_DIR}GeoLite2-City.mmdb)")
    parser.add_argument("--asn", default=os.path.join(DEFAULT_DB_DIR, "GeoLite2-ASN.mmdb"), help=f"ASN 数据库路径 (默认: {DEFAULT_DB_DIR}GeoLite2-ASN.mmdb)")
    parser.add_argument("-i", "--interval", choices=['today', 'weekly', 'monthly'], default='today', help=f"统计维度 当天,本周,本月 (默认: 当天)")
    parser.add_argument("-w", "--window", type=int, default=60, help=f"重叠判定窗口/秒  (默认: 60)")
    
    args = parser.parse_args()
    analyze_xray_logs(args.file, args.city, args.asn, time_window_seconds=args.window, interval=args.interval)