#!/bin/bash
# vmstat-monitor.sh - Script semplice per monitoraggio vmstat in formato CSV con riavvio Apache

# ===========================================
# CONFIGURAZIONE
# ===========================================
DURATION=1000000        # Durata in secondi 
INTERVAL=2          # Intervallo campionamento in secondi
APACHE_RESTART_INTERVAL=360  # Riavvio Apache ogni 6 minuti (360s)
FIRST_RESTART_DELAY=330      # Primo riavvio dopo 330 secondi (5.5 minuti)
OUTPUT_DIR="/var/log/performance"
OUTPUT_FILE=""


# ===========================================
# FUNZIONI
# ===========================================
show_help() {
    echo "Uso: $0 [DURATA_SECONDI] [FILE_OUTPUT]"
    echo ""
    echo "Parametri:"
    echo "  FILE_OUTPUT      Nome file output (default: auto-generato)"
    echo ""
    echo "Funzionalità:"
    echo "  - Monitoraggio vmstat continuo"
    echo "  - Riavvio Apache ogni 6 minuti automatico"
    echo "  - Marker CSV per separare le sessioni"
    echo ""
    echo "Esempi:"
    echo "  $0                    # 5 minuti, file auto"
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
    echo "timestamp,processes_running,processes_blocked,memory_swap_used,memory_free,memory_buffer,memory_cache,swap_in,swap_out,blocks_in,blocks_out,interrupts,context_switches,cpu_user,cpu_system,cpu_idle,cpu_wait,cpu_stolen,load_avg_1min,memory_total,memory_used_percent,session_marker" > "$OUTPUT_FILE"
}

restart_apache_and_mark() {
    local restart_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo ""
    echo "🔄 [$restart_time] Riavviando Apache..."
    
    # Aggiungi marker INIZIO RIAVVIO nel CSV
    echo "$restart_time,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,SESSION_END" >> "$OUTPUT_FILE"
    
    # Riavvia Apache
    sudo systemctl restart apache2
    local restart_result=$?
    
    if [ $restart_result -eq 0 ]; then
        echo "   ✓ Apache riavviato con successo"
        
        # Pausa per stabilizzazione
        sleep 3
        
        # Aggiungi marker NUOVA SESSIONE nel CSV
        local new_session_time=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$new_session_time,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,SESSION_START" >> "$OUTPUT_FILE"
        
        echo "   ✓ Nuova sessione avviata"
    else
        echo "   ✗ Errore nel riavvio Apache"
        echo "$restart_time,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,RESTART_FAILED" >> "$OUTPUT_FILE"
    fi
    echo ""
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
echo "   Monitoraggio vmstat + Riavvio Apache -> CSV"
echo "================================================="
echo "Durata: $DURATION secondi ($((DURATION/60)) minuti)"
echo "Intervallo vmstat: $INTERVAL secondi"
echo "Primo riavvio Apache dopo: $((FIRST_RESTART_DELAY/60)) minuti ($FIRST_RESTART_DELAY secondi)"
echo "Riavvii successivi ogni: $((APACHE_RESTART_INTERVAL/60)) minuti ($APACHE_RESTART_INTERVAL secondi)"
echo "Campioni attesi: $((DURATION/INTERVAL))"

setup_output
echo "File output: $OUTPUT_FILE"
echo ""

# Crea header CSV
create_csv_header

# Aggiungi marker sessione iniziale
INITIAL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "$INITIAL_TIME,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,SESSION_START" >> "$OUTPUT_FILE"

echo "Riavvio Apache iniziale per iniziare sessione pulita..."
restart_apache_and_mark

echo "Avvio monitoraggio con riavvii Apache automatici..."
echo "Marker CSV: SESSION_START, SESSION_END per separare le sessioni"
echo "Premi Ctrl+C per interrompere prima della fine"
echo ""

# Contatori per progresso
SAMPLES_COLLECTED=0
SESSION_NUMBER=1
START_TIME=$(date +%s)
LAST_APACHE_RESTART=$START_TIME
FIRST_RESTART_DONE=false

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
    echo "$END_TIME_MARKER,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,SESSION_END" >> "$OUTPUT_FILE"
    
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
    echo "Sessioni Apache: $SESSION_NUMBER"
    echo "Riavvii Apache: $((ACTUAL_DURATION / APACHE_RESTART_INTERVAL))"
    echo "Dimensione file: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo ""
    
    if [ $SAMPLES_COLLECTED -gt 0 ]; then
        echo "Marker sessioni nel file:"
        grep "SESSION_" "$OUTPUT_FILE" | head -10
        echo ""
        echo "Per separare le sessioni manualmente:"
        echo "  grep -n 'SESSION_START\\|SESSION_END' '$OUTPUT_FILE'"
    fi
}

trap cleanup SIGINT SIGTERM

# ===========================================
# RACCOLTA DATI CON RIAVVII APACHE
# ===========================================

# Ottieni informazioni sistema
TOTAL_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Funzione per processare vmstat in background
collect_vmstat_data() {
    while read line; do
        CURRENT_TIME=$(date +%s)
        
        # Controlla se è ora di riavviare Apache
        if [ "$FIRST_RESTART_DONE" = false ]; then
            # Primo restart dopo FIRST_RESTART_DELAY secondi
            if [ $((CURRENT_TIME - LAST_APACHE_RESTART)) -ge $FIRST_RESTART_DELAY ]; then
                SESSION_NUMBER=$((SESSION_NUMBER + 1))
                restart_apache_and_mark
                LAST_APACHE_RESTART=$CURRENT_TIME
                FIRST_RESTART_DONE=true
                echo "   ℹ️ Primo restart completato dopo $FIRST_RESTART_DELAY secondi"
            fi
        else
            # Restart successivi ogni APACHE_RESTART_INTERVAL secondi
            if [ $((CURRENT_TIME - LAST_APACHE_RESTART)) -ge $APACHE_RESTART_INTERVAL ]; then
                SESSION_NUMBER=$((SESSION_NUMBER + 1))
                restart_apache_and_mark
                LAST_APACHE_RESTART=$CURRENT_TIME
            fi
        fi
        
        # Skip header lines di vmstat
        if [[ $line =~ ^[[:space:]]*[0-9] ]]; then
            # Estrai valori da vmstat
            read -r processes_running processes_blocked memory_swap_used memory_free memory_buffer memory_cache swap_in swap_out blocks_in blocks_out interrupts context_switches cpu_user cpu_system cpu_idle cpu_wait cpu_stolen <<< "$line"
            
            # Calcola timestamp
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            
            # Calcola metriche aggiuntive
            load_avg_1min=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
            memory_used=$((TOTAL_MEMORY - memory_free))
            memory_used_percent=$(echo "scale=2; $memory_used * 100 / $TOTAL_MEMORY" | bc 2>/dev/null || echo "0")
            
            # Scrivi riga CSV normale
            echo "$timestamp,$processes_running,$processes_blocked,$memory_swap_used,$memory_free,$memory_buffer,$memory_cache,$swap_in,$swap_out,$blocks_in,$blocks_out,$interrupts,$context_switches,$cpu_user,$cpu_system,$cpu_idle,$cpu_wait,$cpu_stolen,$load_avg_1min,$TOTAL_MEMORY,$memory_used_percent,DATA" >> "$OUTPUT_FILE"
            
            # Aggiorna contatori
            SAMPLES_COLLECTED=$((SAMPLES_COLLECTED + 1))
            
            # Mostra progresso ogni 30 secondi
            if [ $((SAMPLES_COLLECTED % 15)) -eq 0 ]; then
                elapsed=$((SAMPLES_COLLECTED * INTERVAL))
                remaining=$((DURATION - elapsed))
                
                # Calcola tempo al prossimo restart
                if [ "$FIRST_RESTART_DONE" = false ]; then
                    time_to_next_restart=$((FIRST_RESTART_DELAY - (CURRENT_TIME - LAST_APACHE_RESTART)))
                    restart_type="PRIMO"
                else
                    time_to_next_restart=$((APACHE_RESTART_INTERVAL - (CURRENT_TIME - LAST_APACHE_RESTART)))
                    restart_type="NORMALE"
                fi
                
                echo "[$(date '+%H:%M:%S')] Sessione $SESSION_NUMBER | Progresso: ${elapsed}s/${DURATION}s | Campioni: $SAMPLES_COLLECTED | Prossimo restart ($restart_type): ${time_to_next_restart}s"
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
echo "$FINAL_TIME,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,SESSION_END" >> "$OUTPUT_FILE"

# Mostra risultati
show_results