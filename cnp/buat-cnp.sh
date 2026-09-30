#!/bin/bash

generate_cnp() {
    local total_rules=$1
    local filename="cnp-${total_rules}.yaml"
    local dummy_port_start=15000

    echo "Menciptakan ${filename} dengan ${total_rules} aturan..."

    cat <<YAML > "$filename"
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: netperf-policy-standard
spec:
  endpointSelector:
    matchLabels:
      run: netperf-tujuan
  ingress:
    - fromEndpoints:
        - matchLabels:
            run: netperf-sumber
      toPorts:
YAML

    local rule_count=0
    local block_count=0

    while [ "$rule_count" -lt "$total_rules" ]; do
        echo "        - ports:" >> "$filename"
        block_count=0

        # Baris pertama murni untuk Netperf (Port 5200 sampai 5315)
        if [ "$rule_count" -eq 0 ]; then
            cat <<YAML >> "$filename"
            - port: "5200"
              endPort: 5315
              protocol: TCP
YAML
            ((rule_count++))
            ((block_count++))
        fi

        # Mengisi sisa slot dengan port dummy hingga maksimal 40 per blok
        while [ "$block_count" -lt 40 ] && [ "$rule_count" -lt "$total_rules" ]; do
            local current_dummy_port=$((dummy_port_start + rule_count))
            cat <<YAML >> "$filename"
            - port: "${current_dummy_port}"
              protocol: TCP
YAML
            ((rule_count++))
            ((block_count++))
        done
    done

    echo "Selesai: $filename"
}

# ==========================================
# BAGIAN INTERAKTIF
# ==========================================
echo "=========================================="
echo "   Cilium Network Policy (CNP) Generator  "
echo "=========================================="
echo "Masukkan jumlah rule yang ingin dibuat."
echo "Bisa memasukkan banyak angka sekaligus dipisah spasi (Contoh: 1000 2000 10000)"
read -p "Input: " user_inputs

# Validasi jika kosong
if [ -z "$user_inputs" ]; then
    echo "Input kosong. Dibatalkan."
    exit 1
fi

echo ""
# Looping untuk memproses semua angka yang diketikkan
for num in $user_inputs; do
    if [[ "$num" =~ ^[0-9]+$ ]]; then
        generate_cnp "$num"
    else
        echo "Abaikan '$num': Bukan angka yang valid."
    fi
done
