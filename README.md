# Apache Minimal Web Server for Capacity Testing

Configurazione minimale di Apache per servire file di diverse dimensioni per capacity testing.

## Struttura del Progetto

```
apache-config-repo/
├── config/
│   └── minimal.conf        # Configurazione Apache minimale
├── deploy.sh              # Script di deployment automatico
└── README.md              # Documentazione
```

## Endpoints Disponibili

- `/small` - File da ~1KB
- `/medium` - File da ~10KB  
- `/large` - File da ~100KB
- `/xlarge` - File da ~1MB
- `/xxlarge` - File da ~10MB

## Deployment su Ubuntu 22.04 LTS

```bash
# Clona la repository
git clone <repo-url> apache-capacity-test
cd apache-capacity-test

# Esegui deployment (lo script si auto-corregge i permessi)
./deploy.sh
```

**Prerequisiti:**
- Ubuntu 22.04 LTS
- Apache2 installato (`sudo apt install apache2`)
- Accesso sudo

Lo script di deployment:
- **Auto-fix permessi**: rende se stesso eseguibile automaticamente
- **Genera file di test**: 5 file di dimensioni diverse (1KB - 10MB)
- **Configura Apache**: alias per routing semplificato
- **Fix permessi**: risolve problemi di accesso directory
- **Test automatico**: verifica che tutti gli endpoint funzionino
- **Diagnostica avanzata**: suggerisce comandi debug in caso di errori

## Test degli Endpoint

### Dal Server (verifica locale)
```bash
# Test manuale con curl
curl http://localhost/small
curl http://localhost/medium
curl http://localhost/large
curl http://localhost/xlarge  
curl http://localhost/xxlarge

# Test con timing
curl -w "Time: %{time_total}s, Size: %{size_download} bytes\n" -o /dev/null -s http://localhost/small
```

### Dal Client (per capacity testing)
```bash
# Sostituisci SERVER_IP con l'IP del tuo server
curl http://SERVER_IP/small
curl http://SERVER_IP/medium
curl http://SERVER_IP/large
curl http://SERVER_IP/xlarge
curl http://SERVER_IP/xxlarge

# Server status (per monitoring)
curl http://SERVER_IP/status
```

## Configurazione Apache

La configurazione `minimal.conf` è estremamente semplificata:
- **Alias diretti** per routing ai file di test
- **No caching** per test accurati  
- **Permessi base** per accesso pubblico
- **Minimo overhead** di processing

## Monitoring

```bash
# Status Apache real-time
curl http://localhost/status

# Log Apache in tempo reale
sudo tail -f /var/log/apache2/access.log
sudo tail -f /var/log/apache2/error.log

# Risorse sistema
htop
sudo systemctl status apache2
```

## Personalizzazione

### Modificare dimensioni file
Edita le sezioni `dd` in `deploy.sh`:
```bash
# Esempio: file da 5MB invece di 1MB
sudo dd if=/dev/zero of="$APACHE_DOC_ROOT/test-files/xlarge.dat" bs=1024 count=5120
```

### Aggiungere nuovi endpoint
1. Genera nuovo file in `deploy.sh`
2. Aggiungi alias in `config/minimal.conf`
3. Aggiungi test nel loop di verifica

## Troubleshooting

### Se deployment fallisce

Il script include diagnostica automatica. In caso di errori:

```bash
# Controlla log Apache
sudo tail /var/log/apache2/error.log

# Verifica moduli abilitati  
sudo apache2ctl -M | grep alias

# Controlla permessi file
ls -la /var/www/html/test-files/

# Test configurazione Apache
sudo apache2ctl configtest
```

### Errori comuni

**403 Forbidden - Search permission missing:**
```bash
# Fix permessi directory
sudo chmod 755 /var/www/html/test-files/
sudo systemctl restart apache2
```

**Modulo alias non trovato:**
```bash
# Abilita modulo alias
sudo a2enmod alias
sudo systemctl restart apache2
```

**ServerName warning:**
```bash
# Il deploy.sh risolve automaticamente questo problema
echo "ServerName localhost" | sudo tee /etc/apache2/conf-available/servername.conf
sudo a2enconf servername
```

## Note Importanti

- **Solo per testing**: configurazione minimale, non per produzione
- **No caching**: ogni richiesta colpisce il server realmente
- **File binari**: ottimizzati per test di throughput
- **Auto-diagnostica**: lo script ti guida nella risoluzione problemi
- **Ubuntu 22.04 LTS**: specificamente testato e ottimizzato