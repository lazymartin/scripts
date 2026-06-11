#!/bin/bash

# ================= 配置区域 =================
SERVER="127.0.0.1:${xray_api_port}"
LOG_FILE="/var/log/xray/traffic_daily.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# 在这里填入你所有的用户 email (使用空格分隔)
USERS=("${user_1}" "${user_2}")

# 历史累计流量数据存放目录
DATA_DIR="/var/log/xray/data"
mkdir -p "$DATA_DIR"
# ============================================

# 写入一条分隔线，方便在日志中区分每次的记录
echo "========== 统计时间: $DATE ==========" >> "$LOG_FILE"

# 遍历数组中的每一个用户
for USER_EMAIL in "${USERS[@]}"; do
    # 1. 获取本次增量并严格执行 -reset 清空 API 内部计数
    DOWNLINK_DELTA=$(xray api stats -server=$SERVER -name "user>>>${USER_EMAIL}>>>traffic>>>downlink" -reset 2>/dev/null | jq -r '.stat.value' || echo "0") # -reset 清空流量数据
    UPLINK_DELTA=$(xray api stats -server=$SERVER -name "user>>>${USER_EMAIL}>>>traffic>>>uplink" -reset 2>/dev/null | jq -r '.stat.value' || echo "0")

    # 兜底空值处理（使用规范的 if 结构避免隐藏报错）
    if [ -z "$DOWNLINK_DELTA" ] || [ "$DOWNLINK_DELTA" = "null" ]; then DOWNLINK_DELTA=0; fi
    if [ -z "$UPLINK_DELTA" ] || [ "$UPLINK_DELTA" = "null" ]; then UPLINK_DELTA=0; fi

    # 计算本次增量（当天）的 MB 值
    TODAY_TOTAL_BYTES=$((UPLINK_DELTA + DOWNLINK_DELTA))
    TODAY_TOTAL_MB=$(awk "BEGIN {printf \"%.2f\", $TODAY_TOTAL_BYTES / 1024 / 1024}")
    TODAY_UP_MB=$(awk "BEGIN {printf \"%.2f\", $UPLINK_DELTA / 1024 / 1024}")
    TODAY_DOWN_MB=$(awk "BEGIN {printf \"%.2f\", $DOWNLINK_DELTA / 1024 / 1024}")

    # 2. 读取硬盘文件中本月已有的历史累计流量
    STORE_FILE="$DATA_DIR/${USER_EMAIL}.data"
    if [ -f "$STORE_FILE" ]; then
        read -r STORED_UP STORED_DOWN < "$STORE_FILE"
    else
        STORED_UP=0
        STORED_DOWN=0
    fi

    # 3. 历史数据与本次增量相加
    NEW_UP=$((STORED_UP + UPLINK_DELTA))
    NEW_DOWN=$((STORED_DOWN + DOWNLINK_DELTA))
    TOTAL_BYTES=$((NEW_UP + NEW_DOWN))

    # 4. 转换月度累计流量为 MB
    TOTAL_MB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_BYTES / 1024 / 1024}")
    UP_MB=$(awk "BEGIN {printf \"%.2f\", $NEW_UP / 1024 / 1024}")
    DOWN_MB=$(awk "BEGIN {printf \"%.2f\", $NEW_DOWN / 1024 / 1024}")

    # 5. 写入日志
    echo "用户: $USER_EMAIL | 本次增量: $TODAY_TOTAL_MB MB (上:$TODAY_UP_MB/下:$TODAY_DOWN_MB) | 本月累计: $TOTAL_MB MB (上:$UP_MB/下:$DOWN_MB)" >> "$LOG_FILE"

    # 6. 保存数据并判断是否为月初重置
    if [ "$(date +"%d")" = "01" ]; then
        # 如果今天是 1 号，直接用今天的增量覆盖文件，丢弃上个月的历史数据
        echo "$UPLINK_DELTA $DOWNLINK_DELTA" > "$STORE_FILE"
        echo "[系统通知] 用户 $USER_EMAIL 新月开始，本月累计数据已重置。" >> "$LOG_FILE"
    else
        # 非 1 号则正常将累加后的总量保存
        echo "$NEW_UP $NEW_DOWN" > "$STORE_FILE"
    fi
done

# 写入结束空行
echo "" >> "$LOG_FILE"
