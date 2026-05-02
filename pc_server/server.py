import subprocess
import datetime
import pyautogui #Gestos/mouse/teclado
import psutil #RAM e CPU
from flask import Flask, request
from flask_socketio import SocketIO, emit
try:
    import screen_brightness_control as sbc
    sbc_available = True
except ModuleNotFoundError:
    sbc = None
    sbc_available = False
import os
from dotenv import load_dotenv

load_dotenv()

meu_token = os.getenv('TOKEN_AUTENTICACAO')


# Desativa o "fail-safe" (opcional, mas evita que o script pare se o mouse for para o canto da tela)
pyautogui.FAILSAFE = False

psutil.cpu_percent(interval=None)

app = Flask(__name__)
# O SocketIO permite a comunicação em tempo real com o app Flutter
socketio = SocketIO(app, cors_allowed_origins="*")

def registrar_log(mensagem):
    """Função auxiliar para registrar ações em um arquivo de texto."""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open("historico_automacao.txt", "a") as arquivo:
        arquivo.write(f"[{timestamp}] - {mensagem}\n")

@socketio.on('connect')
def handle_connect():
    """Evento disparado quando o celular se conecta ao PC."""
    print(f"Dispositivo conectado: {request.remote_addr}")
    emit('status_conexao', {'mensagem': 'Conectado ao EcoHost Sentinel'})

@socketio.on('request_stats')
def handle_stats(data=None):
    """Coleta e envia dados de telemetria do hardware via psutil."""

    # None evita que o servidor "congele" por 1 segundo
    cpu = psutil.cpu_percent(interval=0.1)
    ram = psutil.virtual_memory().percent

    # Cálculo correto do Uptime
    import time
    tempo_ligado = time.time() - psutil.boot_time()
    uptime_formatado = str(datetime.timedelta(seconds=int(tempo_ligado)))

    stats = {
        'cpu_uso': cpu,
        'ram_uso': ram,
        'uptime': uptime_formatado
    }

    # Envia os dados de volta para quem pediu
    emit('receive_stats', stats)
    print(f"Status enviados: CPU {cpu}% | RAM {ram}%")

@socketio.on('keyboard_type')
def handle_keyboard_type(data):
    """Recebe texto do celular e digita no PC."""
    texto = data.get('text', '')
    if texto:
        # O interval dá um aspecto mais natural à digitação (opcional)
        pyautogui.write(texto, interval=0.05)
        print(f"Digitado no PC: {texto}")

@socketio.on('keyboard_key')
def handle_keyboard_key(data):
    """Pressiona teclas especiais (Enter, Backspace, etc)."""
    key = data.get('key', '')
    if key:
        pyautogui.press(key)
        print(f"Tecla pressionada: {key}")

@socketio.on('abortar_desligamento')
def handle_abort():
    try:
        # O comando /a cancela qualquer desligamento agendado
        subprocess.run(["shutdown", "/a"], check=True)
        print(">>> AGENDAMENTO CANCELADO PELO USUÁRIO <<<")
        emit('confirmacao_acao', {'mensagem': 'Desligamento cancelado com sucesso!'})
    except Exception as e:
        print(f"Erro ao abortar: {e}")
        emit('erro_acao', {'mensagem': 'Não há desligamento agendado para cancelar.'})

@socketio.on('mouse_move')
def handle_mouse_move(data):
    """Move o mouse baseado no deslocamento (dx, dy) enviado pelo celular."""
    dx = data.get('dx', 0)
    dy = data.get('dy', 0)

    # Sensibilidade: multiplicamos o movimento para ficar mais fluido
    sensibilidade = 2.0

    # moveRel move o mouse RELATIVAMENTE à posição atual
    pyautogui.moveRel(dx * sensibilidade, dy * sensibilidade)

@socketio.on('mouse_click')
def handle_mouse_click(data):
    """Executa um clique do mouse."""
    botao = data.get('button', 'left') # 'left' ou 'right'
    pyautogui.click(button=botao)

@socketio.on('controle_brilho')
def handle_brilho(data):
    if not sbc_available:
        mensagem = "Controle de brilho não disponível: módulo screen_brightness_control não está instalado."
        print(mensagem)
        emit('erro_acao', {'mensagem': mensagem})
        return

    try:
        acao = data.get('acao')
        brilho_atual = sbc.get_brightness()[0]

        if acao == 'aumentar':
            sbc.set_brightness(min(100, brilho_atual + 10))
        else:
            sbc.set_brightness(max(0, brilho_atual - 10))

        print(f"Brilho ajustado para: {sbc.get_brightness()[0]}%")
    except Exception as e:
        print(f"Erro ao ajustar brilho: {e}")
        emit('erro_acao', {'mensagem': 'Falha ao ajustar brilho. Verifique se o dispositivo suporta controle de brilho.'})

@socketio.on('controle_volume')
def handle_volume(data):
    acao = data.get('acao')

    if acao == 'aumentar':
        pyautogui.press('volumeup')
    elif acao == 'diminuir':
        pyautogui.press('volumedown')
    elif acao == 'mudo':
        pyautogui.press('volumemute')

    print(f"Comando de volume: {acao}")
    
@socketio.on('exec_shutdown')
def handle_shutdown(data):
    if isinstance(data, dict):
        token_recebido = data.get('token')
        tempo_segundos = data.get('tempo', 0)
    else:
        token_recebido = data
        tempo_segundos = 60

    if token_recebido == meu_token:
        registrar_log(f"Comando de desligamento ({tempo_segundos}s) recebido.")

        # O comando 'shutdown -s -t' aceita o tempo em segundos
        subprocess.run(["shutdown", "-s", "-t", str(tempo_segundos)], check=True)

        emit('confirmacao_acao', {'mensagem': f'O computador desligará em {tempo_segundos} segundos.'})
        print(f">>> DESLIGAMENTO AGENDADO PARA EM {tempo_segundos}s <<<")
    else:
        emit('erro_autenticacao', {'mensagem': 'Token inválido!'})

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000, debug=True)