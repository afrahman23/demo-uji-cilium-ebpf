rm -f /tmp/netperf-rr-*.out
echo "Menjalankan 16 sesi TCP_RR paralel..."
for i in $(seq 0 15); do
    cp=$((5200+i))
    dp=$((5300+i))
    netperf -s 2 -P 0 -6 -H 2001:xxxx:xxxx:xxxx::xxx -p "$cp" -t TCP_RR -l 10 -- -P ",$dp" -r 1,1 -O MEAN_LATENCY,P99_LATENCY,REQUEST_SIZE,RESPONSE_SIZE,TRANSACTION_RATE > /tmp/netperf-rr-$((i+1)).out 2>&1 &
done
wait
echo -e "\n===== TCP_RR PER SESSION ====="
awk '
NF >= 5 && $1 ~ /^[0-9]+([.][0-9]+)?$/ && $5 ~ /^[0-9]+([.][0-9]+)?$/ {
    n++
    printf "Session %02d : Mean=%8.2f us | P99=%8.2f us | TPS=%10.2f\n", n, $1, $2, $5
    mean += $1; p99 += $2; tps += $5
    if ($2 > worst) worst=$2
}
END {
    if(n>0) {
        printf "\nMean latency : %.2f us\n", mean/n
        printf "Mean P99     : %.2f us\n", p99/n
        printf "Worst P99    : %.2f us\n", worst
        printf "Aggregate TPS: %.2f ops/s\n", tps
        printf "\nTPS graph: "
        blocks = int(tps / 500)
        for(i=0; i<blocks; i++) printf "█"
        printf " %.2f ops/s\n", tps
    } else {
        print "Gagal mendapatkan data valid."
    }
}' /tmp/netperf-rr-*.out
