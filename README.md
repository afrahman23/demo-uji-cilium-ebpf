# demo-uji-cilium-ebpf  ⚡️ 

<h2 align="center">
  <img src="https://github.com/afrahman23/demo-uji-cilium-ebpf/blob/main/img/image.png" alt="intranet" width="100%">
</h2>

Alur mekanisme lookup peta eBPF (cilium_policy)

---
## Scenario
Skenario Uji Peningkatan Kebijakan Jaringan (Network Policy) Kubernetes

Setelah pembuktian default-deny, tahap selanjutnya menjalankan kompleksitas policy dengan menaikan rule-set bertahap dari 1000, 2000 sampai 76000 secara gradual.

---

## Demonstrasi Uji

**Pengecekan Port *Listening* (Default 12865 & 12866):**

```bash
kubectl exec netperf-tujuan -- ss -lntp | grep 12865
kubectl exec netperf-tujuan -- ss -lntp | grep 12866

```

**Uji Latensi Tunggal / TCP_RR — 1 session:**

```bash
kubectl exec netperf-sumber-super -- \
netperf -s 2 -P 0 -6 \
-H 2001:xxx:xxxx:xxx::xxx \
-p 5200 \
-t TCP_RR -l 10 \
-- -P ,5300 -r 1,1 \
-O MEAN_LATENCY,P99_LATENCY,REQUEST_SIZE,RESPONSE_SIZE,TRANSACTION_RATE
```

**Uji Latensi TCP_RR — 16 parallel sessions:**

```bash
kubectl exec netperf-sumber-super -- sh -lc '
for i in $(seq 0 15); do
  cp=$((5200+i))
  dp=$((5300+i))
  netperf -s 2 -P 0 -6 \
    -H 2001:xxx:xxxx:xxx::xxx \
    -p "$cp" \
    -t TCP_RR -l 10 \
    -- -P ",$dp" -r 1,1 \
    -O MEAN_LATENCY,P99_LATENCY,REQUEST_SIZE,RESPONSE_SIZE,TRANSACTION_RATE \
    >/tmp/netperf-rr-$((i+1)).out 2>&1 &
done
wait
'
```

**Uji Throughput Tunggal / TCP_STREAM — 1 session:**

```bash
kubectl exec netperf-sumber-super -- \
netperf -s 2 -P 0 -6 \
-H 2001:xxx:xxxx:xxx::xxx \
-p 5200 \
-t TCP_STREAM -l 10 \
-- -P ,5300
```

**Uji Throughput TCP_STREAM — 16 parallel sessions:**

```bash
kubectl exec netperf-sumber-super -- sh -lc '
for i in $(seq 0 15); do
  cp=$((5200+i))
  dp=$((5300+i))
  netperf -s 2 -P 0 -6 \
    -H 2001:xxx:xxxx:xxx::xxx \
    -p "$cp" \
    -t TCP_STREAM -l 10 \
    -- -P ",$dp" \
    >/tmp/netperf-stream-$((i+1)).out 2>&1 &
done
wait
'
```


> **Flag Netperf:**
> * `-p 12865`: Mengarahkan koneksi *control* ke *port* default netserver.
> * `-t TCP_STREAM`: Menentukan jenis uji *throughput*.
> * `-l 10`: Menetapkan durasi pengujian (10 detik).
> * `-O THROUGHPUT,THROUGHPUT_UNITS`: Flag *Omni Output* untuk membersihkan tabel bawaan netperf, sehingga hanya metrik (Mbps) yang ditampilkan.
> * `-- -P ,12866`: Menetapkan *remote data port* secara spesifik ke 12866.
> 
> 

---

## Skenario Pengujian Utama via skrip via skrip (Concurrency 16 Sesi)

Pengujian  *workload* yang sama (16 sesi) untuk membandingkan kondisi *Baseline* (Tanpa CNP) dengan perlakuan *Policy* bertingkat (CNP 1000, 2000, dan 7800). Demo konkurensi visualisasi dibuat dalam skrip wrapper: `demo-stream.sh` dan `demo-rr.sh`.

Pastikan tidak ada *policy* yang aktif. Jalankan skrip secara langsung ke dalam pod `netperf-sumber-super`.

```bash
# 1. TCP_STREAM — 16 paralel + agregasi throughput
kubectl exec -i netperf-sumber-super -- sh < demo-stream.sh

# 2. TCP_RR — 16 paralel + Mean/P99/TPS
kubectl exec -i netperf-sumber-super -- sh < demo-rr.sh

```

---
Rujukan perintah for-loop untuk memetakan thread ke port TCP.
“Linux Performance Tuning Guide.” Intel Corporation, Jul. 19, 2025. [Online]. Available: https://edc.intel.com/content/www/us/en/design/products/ethernet/perf-tuning-guide-800-series-linux/1.4/%E2%80%8Bnetperf/