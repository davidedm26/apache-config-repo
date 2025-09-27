# Apache Minimal Web Server for JMeter Capacity Testing

Configurazione minimale di Apache per servire file di diverse dimensioni per capacity testing con JMeter.

## Struttura del Progetto

```
apache-config-repo/
├── config/
│   └── minimal.conf        # Configurazione Apache ottimizzata
├── jmeter/
│   └── capacity-test.jmx   # Piano di test JMeter
├── deploy.sh              # Script di deployment
└── README.md              # Documentazione
```

## Endpoints Disponibili

- `/small` - File da ~1KB
- `/medium` - File da ~10KB  
- `/large` - File da ~100KB
- `/xlarge` - File da ~1MB
- `/xxlarge` - File da ~10MB

## Deployment su Server Linux

```bash
# Clona la repository
git clone <repo-url> apache-capacity-test
cd apache-capacity-test

# Rendi eseguibile lo script
chmod +x deploy.sh

# Deploy (richiede sudo)
sudo ./deploy.sh
```

Lo script:
- Rileva automaticamente la distribuzione Linux (Ubuntu/Debian o CentOS/RHEL)
- Configura Apache con impostazioni ottimizzate per capacity test
- Genera i file di test di diverse dimensioni
- Configura le rotte per servire i file
- Riavvia Apache

## Test degli Endpoint

```bash
# Test manuale con curl
curl http://localhost/small
curl http://localhost/medium
curl http://localhost/large
curl http://localhost/xlarge  
curl http://localhost/xxlarge

# Status del server (per monitoring)
curl http://localhost/status
```

## Capacity Testing con JMeter

### Dal Client (tua macchina)

1. **Interfaccia Grafica:**
   ```bash
   jmeter
   # Apri il file jmeter/capacity-test.jmx
   # Modifica SERVER variable con l'IP del server
   # Esegui il test
   ```

2. **Command Line:**
   ```bash
   jmeter -n -t jmeter/capacity-test.jmx -l results.jtl -JSERVER=192.168.1.100
   ```

3. **Con parametri personalizzati:**
   ```bash
   jmeter -n -t jmeter/capacity-test.jmx \
     -l results.jtl \
     -JSERVER=192.168.1.100 \
     -JPORT=80 \
     -Jthreads=100 \
     -Jrampup=60
   ```

### Configurazione Test JMeter

Il piano di test incluso:
- **50 thread concorrenti** (modificabile)
- **10 iterazioni** per thread
- **30 secondi** di ramp-up
- **Testa tutti e 5 gli endpoint** in modo distribuito
- **Keep-alive abilitato** per performance realistiche
- **Salvataggio risultati** in formato JTL

## Configurazione Apache

La configurazione `minimal.conf` include:
- **MPM Event** ottimizzato per alta concorrenza
- **Keep-alive** configurato per performance
- **No caching** per test accurati
- **Server status** per monitoring
- **Alias semplici** per routing diretto ai file

## Monitoring

Durante i test puoi monitorare:
```bash
# Status Apache real-time
curl http://server-ip/status

# Log Apache
sudo tail -f /var/log/apache2/access.log  # Ubuntu/Debian
sudo tail -f /var/log/httpd/access_log    # CentOS/RHEL

# Risorse sistema
htop
iotop
```

## Personalizzazione

### Modificare dimensioni file
Edita `deploy.sh` nella sezione di generazione file per cambiare le dimensioni.

### Modificare configurazione Apache
Edita `config/minimal.conf` per ottimizzazioni specifiche.

### Modificare test JMeter
Edita `jmeter/capacity-test.jmx` per:
- Numero di thread
- Durata test
- Pattern di carico
- Endpoint da testare

## Troubleshooting

### Problemi comuni

1. **Permessi negati:**
   ```bash
   sudo chown -R www-data:www-data /var/www/html/test-files  # Ubuntu
   sudo chown -R apache:apache /var/www/html/test-files      # CentOS
   ```

2. **Apache non si riavvia:**
   ```bash
   sudo apache2ctl configtest  # Testa configurazione
   sudo systemctl status apache2
   ```

3. **Endpoint non raggiungibili:**
   ```bash
   # Verifica file esistano
   ls -la /var/www/html/test-files/
   
   # Verifica configurazione
   sudo apache2ctl -S
   ```

## Note

- Configurazione ottimizzata per testing, non per produzione
- Disabilita caching per risultati accurati
- Usa file binari per evitare overhead di processing
- Include monitoring built-in per analisi real-time