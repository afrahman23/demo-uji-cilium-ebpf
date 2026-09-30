#!/bin/bash
# cek-resource-csv.sh
#
# Mengukur CPU dan memory worker dengan SAR pada window pengujian yang sama.
#
# Workflow:
#   1) ./cek-resource-csv.sh start
#   2) Jalankan 10iterasi.sh / benchmark
#   3) ./cek-resource-csv.sh stop
#
# Output default:
#   ./hasil_resource.csv
#
# Setelah setiap skenario selesai, rename:
#   hasil_resource.csv -> 0.csv
#   hasil_resource.csv -> 1.csv
#   hasil_resource.csv -> 50.csv
#   hasil_resource.csv -> 100.csv 
#   etc... 
#
# Kebutuhan:
#   sysstat (sar)

set -u

STATE_DIR="${HOME}/.netperf-resource"
CPU_LOG="${STATE_DIR}/sar-cpu.log"
MEM_LOG="${STATE_DIR}/sar-mem.log"
CPU_PID_FILE="${STATE_DIR}/sar-cpu.pid"
MEM_PID_FILE="${STATE_DIR}/sar-mem.pid"
META_FILE="${STATE_DIR}/meta"
DEFAULT_OUTPUT="${PWD}/hasil_resource.csv"

mkdir -p "${STATE_DIR}"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

is_running() {
    local pid="$1"
    kill -0 "${pid}" 2>/dev/null
}

read_pid() {
    local file="$1"
    [[ -f "${file}" ]] || return 1
    tr -d '[:space:]' < "${file}"
}

start_measurement() {
    if [[ -f "${CPU_PID_FILE}" ]]; then
        local old_cpu_pid
        old_cpu_pid="$(read_pid "${CPU_PID_FILE}" || true)"
        if [[ -n "${old_cpu_pid}" ]] && is_running "${old_cpu_pid}"; then
            die "measurement sedang berjalan (CPU PID ${old_cpu_pid}). Jalankan 'stop' terlebih dahulu."
        fi
    fi

    local output="${1:-${DEFAULT_OUTPUT}}"
    local start_iso
    start_iso="$(date --iso-8601=seconds)"

    rm -f "${CPU_LOG}" "${MEM_LOG}" "${CPU_PID_FILE}" "${MEM_PID_FILE}" "${META_FILE}"

    # LC_ALL=C menjaga format angka SAR konsisten untuk AWK.
    nohup env LC_ALL=C sar -u 1 </dev/null >"${CPU_LOG}" 2>&1 &
    local cpu_pid=$!

    nohup env LC_ALL=C sar -r 1 </dev/null >"${MEM_LOG}" 2>&1 &
    local mem_pid=$!

    echo "${cpu_pid}" > "${CPU_PID_FILE}"
    echo "${mem_pid}" > "${MEM_PID_FILE}"

    {
        printf 'OUTPUT=%s\n' "${output}"
        printf 'START=%s\n' "${start_iso}"
    } > "${META_FILE}"

    sleep 2

    if ! is_running "${cpu_pid}" || ! is_running "${mem_pid}"; then
        echo "---- CPU SAR LOG ----" >&2
        tail -n 20 "${CPU_LOG}" >&2 || true
        echo "---- MEM SAR LOG ----" >&2
        tail -n 20 "${MEM_LOG}" >&2 || true
        die "gagal menjalankan sar."
    fi

    echo "SAR resource measurement STARTED"
    echo "CPU PID     : ${cpu_pid}"
    echo "Memory PID  : ${mem_pid}"
    echo "Output CSV  : ${output}"
    echo "Start time  : ${start_iso}"
    echo
    echo "Sekarang jalankan benchmark (mis. 10iterasi.sh)."
    echo "Setelah benchmark selesai, jalankan:"
    echo "  $0 stop"
}

stop_measurement() {
    [[ -f "${META_FILE}" ]] || die "tidak ada measurement aktif. Jalankan 'start' terlebih dahulu."

    local cpu_pid=""
    local mem_pid=""
    cpu_pid="$(read_pid "${CPU_PID_FILE}" || true)"
    mem_pid="$(read_pid "${MEM_PID_FILE}" || true)"

    # Hentikan collector; parser akan menghitung semua sample yang sudah terekam.
    [[ -n "${cpu_pid}" ]] && kill "${cpu_pid}" 2>/dev/null || true
    [[ -n "${mem_pid}" ]] && kill "${mem_pid}" 2>/dev/null || true

    # Beri sar sedikit waktu untuk flush log.
    sleep 2

    local output start_iso stop_iso
    output="$(sed -n 's/^OUTPUT=//p' "${META_FILE}")"
    start_iso="$(sed -n 's/^START=//p' "${META_FILE}")"
    stop_iso="$(date --iso-8601=seconds)"

    [[ -n "${output}" ]] || output="${DEFAULT_OUTPUT}"

    local cpu_avg mem_avg cpu_n mem_n
    cpu_avg="$(
        awk '
        $1 ~ /^[0-9]+:[0-9]+:[0-9]+$/ && $0 ~ /all/ && $NF ~ /^[0-9]+([.][0-9]+)?$/ {
            busy = 100 - $NF
            sum += busy
            n++
        }
        END {
            if (n > 0) printf "%.2f", sum/n
            else printf "NA"
        }' "${CPU_LOG}"
    )"

    cpu_n="$(
        awk '
        $1 ~ /^[0-9]+:[0-9]+:[0-9]+$/ && $0 ~ /all/ && $NF ~ /^[0-9]+([.][0-9]+)?$/ { n++ }
        END { print n+0 }
        ' "${CPU_LOG}"
    )"

    mem_avg="$(
        awk '
        $1 ~ /^[0-9]+:[0-9]+:[0-9]+$/ && $2 != "kbmemfree" && $5 ~ /^[0-9]+([.][0-9]+)?$/ {
            sum += $5
            n++
        }
        END {
            if (n > 0) printf "%.2f", sum/n
            else printf "NA"
        }' "${MEM_LOG}"
    )"

    mem_n="$(
        awk '
        $1 ~ /^[0-9]+:[0-9]+:[0-9]+$/ && $2 != "kbmemfree" && $5 ~ /^[0-9]+([.][0-9]+)?$/ { n++ }
        END { print n+0 }
        ' "${MEM_LOG}"
    )"

    [[ "${cpu_avg}" != "NA" ]] || die "CPU sample tidak terbaca dari ${CPU_LOG}"
    [[ "${mem_avg}" != "NA" ]] || die "memory sample tidak terbaca dari ${MEM_LOG}"

    # Durasi dihitung dari timestamp epoch lokal.
    local start_epoch stop_epoch duration
    start_epoch="$(date -d "${start_iso}" +%s 2>/dev/null || true)"
    stop_epoch="$(date -d "${stop_iso}" +%s 2>/dev/null || true)"
    if [[ -n "${start_epoch}" && -n "${stop_epoch}" ]]; then
        duration=$((stop_epoch - start_epoch))
    else
        duration="NA"
    fi

    local hostname_short
    hostname_short="$(hostname -s 2>/dev/null || hostname)"

    cat > "${output}" <<EOF
Hostname,Start_Time,Stop_Time,Duration_s,CPU_Avg_Pct,Memory_Avg_Pct,CPU_Samples,Memory_Samples
${hostname_short},${start_iso},${stop_iso},${duration},${cpu_avg},${mem_avg},${cpu_n},${mem_n}
EOF

    rm -f "${CPU_PID_FILE}" "${MEM_PID_FILE}" "${META_FILE}"

    echo
    echo "===== RESOURCE CSV ====="
    cat "${output}"
    echo
    echo "CSV tersimpan: ${output}"
}

show_status() {
    echo "===== RESOURCE MONITOR STATUS ====="
    if [[ ! -f "${META_FILE}" ]]; then
        echo "STATUS: NOT RUNNING"
        exit 0
    fi

    local cpu_pid mem_pid
    cpu_pid="$(read_pid "${CPU_PID_FILE}" || true)"
    mem_pid="$(read_pid "${MEM_PID_FILE}" || true)"

    echo "Start time : $(sed -n 's/^START=//p' "${META_FILE}")"
    echo "Output     : $(sed -n 's/^OUTPUT=//p' "${META_FILE}")"
    echo "CPU PID    : ${cpu_pid:-NA}"
    echo "Memory PID : ${mem_pid:-NA}"

    if [[ -n "${cpu_pid}" ]] && is_running "${cpu_pid}"; then
        echo "CPU SAR    : RUNNING"
    else
        echo "CPU SAR    : STOPPED"
    fi

    if [[ -n "${mem_pid}" ]] && is_running "${mem_pid}"; then
        echo "Memory SAR : RUNNING"
    else
        echo "Memory SAR : STOPPED"
    fi
}

case "${1:-}" in
    start)
        start_measurement "${2:-${DEFAULT_OUTPUT}}"
        ;;
    stop)
        stop_measurement
        ;;
    status)
        show_status
        ;;
    *)
        cat <<EOF
Usage:
  $0 start [output.csv]
  $0 stop
  $0 status

Contoh:
  $0 start hasil_resource.csv
  # jalankan 10iterasi.sh pada periode ini
  $0 stop

Setelah selesai, rename hasil_resource.csv menjadi:
  0.csv
  1.csv
  50.csv
  100.csv
EOF
        exit 1
        ;;
esac
