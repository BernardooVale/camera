# WebcamStream

Transmite a câmera do Android para o OBS via RTMP, permitindo usar o celular como webcam em entrevistas, reuniões e chamadas de vídeo.

## Como funciona

```
[App Android] → RTMP → [nginx-rtmp] → [OBS Fonte de Mídia] → [OBS Virtual Camera] → [Meet/Zoom/Teams]
```

Via USB: o ADB redireciona a porta do celular para o PC, sem depender de WiFi.  
Via WiFi: o celular transmite direto para o IP do PC na rede local.

---

## Requisitos

### Celular
- Android 5.0+
- Depuração USB ativada (para modo USB)

### PC
- Windows
- OBS Studio 26+ — https://obsproject.com
- nginx-rtmp para Windows — https://github.com/illuspas/nginx-rtmp-win32/releases
- Python 3.x (para modo USB)
- ADB no PATH — https://developer.android.com/studio/releases/platform-tools

---

## Instalação

### 1. nginx-rtmp

1. Baixa o `.zip` mais recente em https://github.com/illuspas/nginx-rtmp-win32/releases
2. Extrai em qualquer pasta (ex: `C:\nginx-rtmp`)
3. Substitui o conteúdo de `conf\nginx.conf` por:

```nginx
worker_processes  1;

events {
    worker_connections  1024;
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            record off;
        }
    }
}
```

### 2. OBS

1. Abre o OBS
2. Na cena, clica `+` em Fontes → Mídia
3. Desmarca "Arquivo local"
4. No campo Entrada: `rtmp://localhost/live`
5. Marca "Reconectar ao terminar"
6. Desmarca "Usar aceleração de hardware"

### 3. App Android

```bash
flutter pub get
flutter run
```

Ou instala direto no celular:

```bash
flutter install
```

---

## Modo de uso

### Via WiFi

1. Roda o `nginx.exe`
2. Abre o OBS — a fonte de Mídia ficará tentando conectar
3. Abre o app no celular
4. No campo IP do PC, digita o IP do PC na rede local
5. Porta: `1935`
6. Toca Iniciar transmissão — a tela do OBS deve mostrar a imagem do celular
7. No OBS, clica Iniciar Virtual Camera (barra inferior direita)
8. No Meet/Zoom/Teams, seleciona OBS Virtual Camera como câmera

### Via USB

1. Ativa Depuração USB no celular:
    - Configurações → Sobre o telefone → toca 7x em "Número da versão"
    - Configurações → Opções do desenvolvedor → Depuração USB → Ativar
2. Conecta o celular via cabo USB
3. Roda o script Python no PC:

```bash
python setup_obs/setup.py
```

4. Roda o `nginx.exe`
5. Abre o OBS
6. Abre o app no celular
7. No campo IP, digita `127.0.0.1`
8. Porta: `1935`
9. Toca Iniciar transmissão
10. No OBS, clica Iniciar Virtual Camera

---

## Estrutura do projeto

```
webcam_stream/
├── lib/
│   ├── main.dart           # entrypoint
│   └── home_page.dart      # UI + lógica de streaming
├── setup_obs/
│   └── setup.py            # script Python — ADB reverse para modo USB
├── android/
│   └── app/
│       └── build.gradle.kts
└── pubspec.yaml
```

---

## Dependências Flutter

| Pacote | Uso |
|--------|-----|
| rtmp_broadcaster | Streaming RTMP via câmera |
| network_info_plus | Detecta IP local do celular |
| shared_preferences | Salva IP e porta entre sessões |
| wakelock_plus | Mantém tela ligada durante transmissão |

---

## Solução de problemas

**Tela preta no OBS**
- Confirma que o `nginx.exe` está rodando
- Confirma que o app está transmitindo (status "Transmitindo 🔴")
- Libera a porta 1935 no firewall:

```cmd
netsh advfirewall firewall add rule name="nginx-rtmp" dir=in action=allow protocol=TCP localport=1935
```

**App não conecta via USB**
- Confirma que o `setup.py` está rodando antes de transmitir
- Confirma que a Depuração USB está ativada
- Verifica se o ADB reconhece o celular: `adb devices`

**"Nenhuma câmera encontrada"**
- Concede permissão de câmera ao app nas configurações do Android

**Virtual Camera não aparece no Meet/Zoom**
- Reinicia o Meet/Zoom após iniciar a Virtual Camera no OBS
