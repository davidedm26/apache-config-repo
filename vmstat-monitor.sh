#!/bin/bash
# vmstat-monitor.sh - Script semplice per monitoraggio vmstat in formato CSV con riavvio Apache

# ===========================================
# CONFIGURAZIONE
# ===========================================
DURATION=11000        # Durata in secondi 
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
    echo "  DURATA_SECONDI   Durata monitoraggio in secondi (default: 1000000)"
    echo "  FILE_OUTPUT      Nome file output (default: auto-generato)"
    echo ""
    echo "Funzionalità:"
    echo "  - Monitoraggio vmstat continuo"
    echo "  - Output in formato CSV"
    echo "  - Timestamp precisi per ogni campione"
    echo ""
    echo "Esempi:"
    echo "  $0                    # Monitoraggio continuo, file auto"
    echo "  $0 600                # 10 minuti, file auto" 
    echo "  $0 1200 test_long.csv # 20 minuti, file specifico"
    echo ""
    echo "File salvati in: $OUTPUT_DIR"
}

setup_output() {
    # Crea directory se non esiste
    sudo mkdir -p "$OUTPUT_DIR"
    sudo chown $USER:$USER "$OUTPUT_DIR" 2>/dev/null || true
    
    # Genera nome file se non specificato
    if [ -z "$OUTPUT_FILE" ]; then
        START_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        OUTPUT_FILE="$OUTPUT_DIR/vmstat_START_${START_TIMESTAMP}.csv"
    else
        # Se specificato, aggiungi timestamp di inizio
        START_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        OUTPUT_FILE="$OUTPUT_DIR/${OUTPUT_FILE%.*}_START_${START_TIMESTAMP}.csv"
    fi
}

create_csv_header() {
    echo "timestamp,r,b,swpd,free,buff,cache,si,so,bi,bo,in,cs,us,sy,id,wa,st" > "$OUTPUT_FILE"
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
echo "   Monitoraggio vmstat -> CSV"
echo "================================================="
echo "Durata: $DURATION secondi ($((DURATION/60)) minuti)"
echo "Intervallo vmstat: $INTERVAL secondi"
echo "Campioni attesi: $((DURATION/INTERVAL))"

setup_output
echo "File output: $OUTPUT_FILE"
echo ""

# Crea header CSV
create_csv_header

echo "Avvio monitoraggio vmstat..."
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
        wait $VMSTAT_PID 2>/dev/null
    fi
    
    # Aggiungi marker fine sessione
    END_TIME_MARKER=$(date '+%Y-%m-%d %H:%M:%S')
    echo "# Monitoraggio terminato: $END_TIME_MARKER" >> "$OUTPUT_FILE"
    
    show_results
    exit 0
}

show_results() {
    END_TIME=$(date +%s)
    ACTUAL_DURATION=$((END_TIME - START_TIME))
    
    # Genera timestamp di fine
    END_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # Rinomina file con timestamp di fine
    OLD_FILE="$OUTPUT_FILE"
    NEW_FILE="${OUTPUT_FILE%.*}_END_${END_TIMESTAMP}.csv"
    mv "$OLD_FILE" "$NEW_FILE"
    OUTPUT_FILE="$NEW_FILE"
    
    echo "================================================="
    echo "       Monitoraggio completato"
    echo "================================================="
    echo "File generato: $OUTPUT_FILE"
    echo "Campioni raccolti: $SAMPLES_COLLECTED"
    echo "Durata effettiva: $ACTUAL_DURATION secondi"
    echo "Dimensione file: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo ""
}

trap cleanup SIGINT SIGTERM

# ===========================================
# RACCOLTA DATI VMSTAT
# ===========================================

# Funzione per processare vmstat in background
collect_vmstat_data() {
    while read line; do
        CURRENT_TIME=$(date +%s)
        
        # Skip header lines di vmstat
        if [[ $line =~ ^[[:space:]]*[0-9] ]]; then
            # Estrai valori da vmstat (usa i nomi esatti di vmstat)
            read -r r b swpd free buff cache si so bi bo in cs us sy id wa st <<< "$line"
            
            # Calcola timestamp
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            
            # Scrivi riga CSV con le metriche esatte di vmstat
            echo "$timestamp,$r,$b,$swpd,$free,$buff,$cache,$si,$so,$bi,$bo,$in,$cs,$us,$sy,$id,$wa,$st" >> "$OUTPUT_FILE"
            
            # Aggiorna contatori
            SAMPLES_COLLECTED=$((SAMPLES_COLLECTED + 1))
            
            # Mostra progresso ogni 30 secondi
            if [ $((SAMPLES_COLLECTED % 15)) -eq 0 ]; then
                elapsed=$((SAMPLES_COLLECTED * INTERVAL))
                remaining=$((DURATION - elapsed))
                echo "[$(date '+%H:%M:%S')] Progresso: ${elapsed}s/${DURATION}s | Campioni: $SAMPLES_COLLECTED | Rimanenti: ${remaining}s"
            fi
        fi
    done
}

# Avvia vmstat e processa con la funzione
timeout $DURATION vmstat $INTERVAL | collect_vmstat_data &

VMSTAT_PID=$!

# Aspetta completamento
wait $VMSTAT_PID
VMSTAT_PID=""

# Aggiungi marker finale
FINAL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "# Monitoraggio terminato: $FINAL_TIME" >> "$OUTPUT_FILE"

# Mostra risultati
show_results