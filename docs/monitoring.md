# Monitoring with Prometheus

## Install Prometheus Server

```bash
curl -sLo /tmp/prometheus.tar.gz https://github.com/prometheus/prometheus/releases/download/v1.4.1/prometheus-1.4.1.linux-amd64.tar.gz
cd /tmp/
tar xfz prometheus.tar.gz

sudo cp prometheus-*/prometheus /usr/bin/
sudo mkdir -p /etc/prometheus
sudo cp prometheus-*/prometheus.yml /etc/prometheus
```

Create a systemd file for the prometheus server:

```bash
sudo tee /etc/systemd/system/prometheus.service <<-'EOF'
[Unit]
Description=Prometheus Server

[Service]
ExecStart=/usr/bin/prometheus -config.file /etc/prometheus/prometheus.yml

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus && sudo systemctl start prometheus
```

### Configuration

```bash
cat /etc/prometheus/prometheus.yml
# my global config
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

  # Attach these labels to any time series or alerts when communicating with
  # external systems (federation, remote storage, Alertmanager).
  external_labels:
      monitor: 'codelab-monitor'

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first.rules"
  # - "second.rules"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['10.20.0.1:9100', '10.20.0.3:9100', '10.20.0.4:9100', '10.20.0.5:9100']
        labels:
          group: 'opnfv'
```

### Grafana

```bash
curl -sLo /tmp/grafana.deb https://grafanarel.s3.amazonaws.com/builds/grafana_4.0.2-1481203731_amd64.deb
sudo apt-get install -y adduser libfontconfig
sudo dpkg -i /tmp/grafana.deb
# Start Grafana service
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl status grafana-server
sudo systemctl enable grafana-server.service
```

#### Grafana Dashboards

Sample Dashboards:

- <https://grafana.net/dashboards/718>

## Node Exporter

Execute this step on each node

```bash
curl -sLo /tmp/node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v0.13.0/node_exporter-0.13.0.linux-amd64.tar.gz
cd /tmp/
tar xfz node_exporter.tar.gz

sudo cp node_exporter-*/node_exporter /usr/bin/
```

### Systemd

```bash
sudo tee /etc/systemd/system/node_exporter.service <<-'EOF'
[Unit]
Description=Node Exporter

[Service]
ExecStart=/usr/bin/node_exporter

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter && sudo systemctl start node_exporter
sudo iptables -A INPUT -s 10.20.0.0/24 -p tcp -m multiport --ports 9100 -m comment --comment "020 prometheus from 10.20.0.0/24" -j ACCEPT
```

### Ubuntu 14.04

```bash
sudo tee /etc/init/node_exporter.conf <<-'EOF'
# Run node_exporter

start on startup

script
   /usr/bin/node_exporter
end script
EOF

sudo service node_exporter start
sudo iptables -A INPUT -s 10.20.0.0/24 -p tcp -m multiport --ports 9100 -m comment --comment "020 prometheus from 10.20.0.0/24" -j ACCEPT
```
