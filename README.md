# 📡 LINK EXTRACTOR & CRAWLER v2.0  
### *Focused Domain Web Crawler — Extração de links por domínio específico*

Este script (`extract.sh`) é um **crawler leve e eficiente**, feito em **Bash**, projetado para **extrair links pertencentes ao mesmo domínio**, seguindo redirecionamentos, resolvendo IPs e organizando tudo de forma clara no terminal.

Ideal para análises de segurança, mapeamento de superfície de ataque, identificação de subdomínios e varreduras de links internas.

---

## ✨ Funcionalidades

✔️ Extração de links somente do mesmo domínio  
✔️ Detecção e exibição de redirecionamentos  
✔️ Resolução de IP com cache (dig, host, getent)  
✔️ Fila de crawling com profundidade configurável  
✔️ Delay aleatório entre requisições para reduzir bloqueios  
✔️ Output colorido e organizado  
✔️ Contabilização final de URLs visitadas, links válidos e subdomínios descobertos  

---

## 🛠️ Requisitos

O script necessita das ferramentas:

- `bash`
- `curl`
- `dig` (opcional, mas recomendado)
- `host` (fallback)
- `getent` (fallback)

### Instalação rápida em Debian/Ubuntu:

```bash
sudo apt install curl dnsutils bind9-host

## 🚀  Uso
Execute o script informando uma URL inicial:
```bash
./extract.sh https://example.com



