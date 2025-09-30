#!/bin/bash
# vmstat-monitor.sh - Script semplice per monitoraggio vmstat in formato CSV

# ===========================================
# CONFIGURAZIONE
# ===========================================
DURATION=30        # Durata in secondi (default: 30 secondi)
INTERVAL=2          # Intervallo campionamento in secondi
OUTPUT_DIR="/var/log/performance"
OUTPUT_FILE=""

# ===========================================
# FUNZIONI
# ===========================================
show_help() {
    echo "Uso: $0 [DURATA_SECONDI] [FILE_OUTPUT]"
    echo ""
    echo "Parametri:"
    echo "  DURATA_SECONDI   Durata monitoraggio in secondi (default: 300 = 5 min)"
    echo "  FILE_OUTPUT      Nome file output (default: auto-generato)"
    echo ""
    echo "Esempi:"
    echo "  $0                    # 5 minuti, file auto"
    echo "  $0 180                # 3 minuti, file auto" 
    echo "  $0 600 test_load.csv  # 10 minuti, file specifico"
    echo ""
    echo "File salvati in: $OUTPUT_DIR"
}

setup_output() {
    # Crea directory se non esiste
    sudo mkdir -p "$OUTPUT_DIR"
    sudo chown $USER:$USER "$OUTPUT_DIR" 2>/dev/null || true
    
    # Genera nome file se non specificato
    if [ -z "$OUTPUT_FILE" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        OUTPUT_FILE="$OUTPUT_DIR/vmstat_${TIMESTAMP}.csv"
    else
        OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_FILE"
    fi
}

create_csv_header() {
    echo "timestamp,processes_running,processes_blocked,memory_swap_used,memory_free,memory_buffer,memory_cache,swap_in,swap_out,blocks_in,blocks_out,interrupts,context_switches,cpu_user,cpu_system,cpu_idle,cpu_wait,cpu_stolen,load_avg_1min,memory_total,memory_used_percent" > "$OUTPUT_FILE"
}

# ===========================================
# PARSING PARAMETRI
# ===========================================
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -n "$1" ]; then
    DURATION="$1"
fi

if [ -n "$2" ]; then
    OUTPUT_FILE="$2"
fi

# ===========================================
# SETUP E AVVIO
# ===========================================
echo "================================================="
echo "       Monitoraggio vmstat -> CSV"
echo "================================================="
echo "Durata: $DURATION secondi ($((DURATION/60)) minuti)"
echo "Intervallo: $INTERVAL secondi"
echo "Campioni attesi: $((DURATION/INTERVAL))"

setup_output
echo "File output: $OUTPUT_FILE"
echo ""

# Crea header CSV
create_csv_header

echo "Avvio monitoraggio..."
echo "Premi Ctrl+C per interrompere prima della fine"
echo ""

# Contatori per progresso
SAMPLES_COLLECTED=0
START_TIME=$(date +%s)

# Funzione cleanup
cleanup() {
    echo ""
    echo "Interruzione richiesta..."
    if [ -n "$VMSTAT_PID" ]; then
        kill $VMSTAT_PID 2>/dev/null
    fi
    show_results
    exit 0
}

show_results() {
    END_TIME=$(date +%s)
    ACTUAL_DURATION=$((END_TIME - START_TIME))
    
    echo "================================================="
    echo "       Monitoraggio completato"
    echo "================================================="
    echo "File generato: $OUTPUT_FILE"
    echo "Campioni raccolti: $SAMPLES_COLLECTED"
    echo "Durata effettiva: $ACTUAL_DURATION secondi"
    echo "Dimensione file: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo ""
    
    if [ $SAMPLES_COLLECTED -gt 0 ]; then
        echo "Prime 3 righe del file:"
        head -4 "$OUTPUT_FILE"
        echo ""
        echo "Ultime 3 righe del file:"
        tail -3 "$OUTPUT_FILE"
    fi
}

trap cleanup SIGINT SIGTERM

# ===========================================
# RACCOLTA DATI
# ===========================================

# Ottieni informazioni sistema per calcoli aggiuntivi
TOTAL_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Avvia vmstat e processa output
timeout $DURATION vmstat $INTERVAL | while read line; do
    # Skip header lines
    if [[ $line =~ ^[[:space:]]*[0-9] ]]; then
        # Estrai valori da vmstat
        read -r processes_running processes_blocked memory_swap_used memory_free memory_buffer memory_cache swap_in swap_out blocks_in blocks_out interrupts context_switches cpu_user cpu_system cpu_idle cpu_wait cpu_stolen <<< "$line"
        
        # Calcola timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Calcola metriche aggiuntive
        load_avg_1min=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
        memory_used=$((TOTAL_MEMORY - memory_free))
        memory_used_percent=$(echo "scale=2; $memory_used * 100 / $TOTAL_MEMORY" | bc 2>/dev/null || echo "0")
        
        # Scrivi riga CSV
        echo "$timestamp,$processes_running,$processes_blocked,$memory_swap_used,$memory_free,$memory_buffer,$memory_cache,$swap_in,$swap_out,$blocks_in,$blocks_out,$interrupts,$context_switches,$cpu_user,$cpu_system,$cpu_idle,$cpu_wait,$cpu_stolen,$load_avg_1min,$TOTAL_MEMORY,$memory_used_percent" >> "$OUTPUT_FILE"
        
        # Aggiorna contatori
        SAMPLES_COLLECTED=$((SAMPLES_COLLECTED + 1))
        
        # Mostra progresso ogni 30 secondi
        if [ $((SAMPLES_COLLECTED % 15)) -eq 0 ]; then
            elapsed=$((SAMPLES_COLLECTED * INTERVAL))
            remaining=$((DURATION - elapsed))
            echo "[$(date '+%H:%M:%S')] Progresso: ${elapsed}s/${DURATION}s - Campioni: $SAMPLES_COLLECTED (rimanenti: ${remaining}s)"
        fi
    fi
done &

VMSTAT_PID=$!

# Aspetta completamento
wait $VMSTAT_PID
VMSTAT_PID=""

# Mostra risultati
show_results