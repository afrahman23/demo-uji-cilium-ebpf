rm -f /tmp/netperf-stream-*.out
echo "Menjalankan 16 sesi TCP_STREAM paralel..."
for i in $(seq 0 15); do
    cp=$((5200+i))
    dp=$((5300+i))
    netperf -s 2 -P 0 -6 -H 2001:xxxx:xxxx:xxxx::xxx -p "$cp" -t TCP_STREAM -l 10 -- -P ",$dp" > /tmp/netperf-stream-$((i+1)).out 2>&1 &
done
wait
echo -e "\n===== TCP_STREAM PER SESSION ====="
sum=0; n=0
for f in $(ls /tmp/netperf-stream-*.out); do
    n=$((n+1))
    v=$(awk '$NF ~ /^-?[0-9]+([.][0-9]+)?$/ { v=$NF } END { if(v!="") print v; else print "0" }' "$f")
    printf "Session %02d : %10.2f Mbps\n" "$n" "$v"
    sum=$(awk -v a="$sum" -v b="$v" 'BEGIN{printf "%.2f", a+b}')
done
avg=$(awk -v s="$sum" -v n="$n" 'BEGIN{if(n>0) printf "%.2f", s/n; else print "0"}')
echo
printf "Aggregate   : %8.2f Mbps\n" "$sum"
printf "Mean/session: %8.2f Mbps\n" "$avg"
echo -n "Aggregate graph: "
awk -v sum="$sum" 'BEGIN { blocks = int(sum / 20); for(i=0; i<blocks; i++) printf "█"; printf " %.2f Mbps\n", sum }'
