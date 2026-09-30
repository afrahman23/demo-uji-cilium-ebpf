#!/bin/bash

# 1. Menyiapkan direktori dan nama file dinamis berdasarkan waktu
mkdir -p benchmark
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUT_FILE="benchmark/hasil_poc_${TIMESTAMP}.csv"

# 2. Buat header file CSV agar siap dibuka di Excel / Python Pandas
echo "Iterasi,Throughput_Mbps,Mean_Latency_us,P99_Latency_us,Aggregate_TPS" > "$OUT_FILE"

echo "Memulai PoC: 10 Iterasi Pengujian Netperf (Interval 10s per tes)..."
echo "Data akan disimpan pada: $OUT_FILE"

# 3. Looping sebanyak 10 kali eksekusi
for i in {1..10}; do
    echo -n "Menjalankan Iterasi $i/10... "

    # Eksekusi TCP_STREAM dan ambil angka aggregate-nya saja
    stream_output=$(kubectl exec -i netperf-sumber-super -- sh < demo-stream.sh)
    mbps=$(echo "$stream_output" | awk '/Aggregate   :/ {print $3}')

    # Eksekusi TCP_RR dan ambil angka Mean, P99, dan TPS-nya saja
    rr_output=$(kubectl exec -i netperf-sumber-super -- sh < demo-rr.sh)
    mean=$(echo "$rr_output" | awk '/Mean latency :/ {print $4}')
    p99=$(echo "$rr_output" | awk '/Mean P99     :/ {print $4}')
    tps=$(echo "$rr_output" | awk '/Aggregate TPS:/ {print $3}')

    # Simpan hasil iterasi ini ke file CSV
    echo "$i,$mbps,$mean,$p99,$tps" >> "$OUT_FILE"
    
    echo "Selesai (Throughput: $mbps Mbps, TPS: $tps)"
    
    # Jeda 2 detik antar iterasi agar koneksi TCP benar-benar tertutup (Time_Wait release)
    sleep 2
done

echo -e "\nPengujian Selesai! Hasil tersimpan di: $OUT_FILE"
cat "$OUT_FILE"
