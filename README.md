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

## Prerequisiti

- **Ubuntu 22.04 LTS**



## Installazione Apache

### 1. **Aggiorna il sistema**
```bash
sudo apt update
sudo apt upgrade -y
```

### 2. **Installa Apache 2**
```bash
# Installa Apache2 e utilità
sudo apt install apache2 apache2-utils -y
```

### 3. **Avvia e configura Apache**
```bash
# Avvia Apache
sudo systemctl start apache2

# Abilita avvio automatico
sudo systemctl enable apache2

# Verifica status
sudo systemctl status apache2
```

### 4. **Configura firewall** (opzionale)
```bash
# Se hai ufw attivo
sudo ufw allow 'Apache'

# Oppure permetti porta 80 direttamente
sudo ufw allow 80
```

### 5. **Test installazione**
```bash
# Test locale
curl http://localhost

# Dovrebbe mostrare la pagina di default di Apache
```

## Deployment su Ubuntu 22.04 LTS

```bash
# Clona la repository
git clone https://github.com/davidedm26/apache-config-repo
cd apache-config-repo

# Esegui deployment 
chmod +x ./deploy.sh
./deploy.sh
```


## Configurazione Apache

La configurazione `minimal.conf` è estremamente semplificata:
- **Alias diretti** per routing ai file di test
- **No caching** per test accurati  
- **Permessi base** per accesso pubblico
- **Minimo overhead** di processing


## Personalizzazione

### Modificare dimensioni file
Edita le sezioni `dd` in `deploy.sh`:
```bash
# Esempio: file da 5MB invece di 1MB
sudo dd if=/dev/zero of="$APACHE_DOC_ROOT/test-files/xlarge.dat" bs=1024 count=5120
```


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

