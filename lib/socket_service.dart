import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  late IO.Socket socket;

  // Stream para enviar dados do Python para a tela do Flutter em tempo real
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  void connect(String ip) {
    socket = IO.io('http://$ip:5000',
        IO.OptionBuilder()
            .setTransports(['websocket']) // Força WebSocket para baixa latência
            .enableAutoConnect()
            .build()
    );

    socket.onConnect((_) {
      print('Conectado ao PC!');
      // Pede atualizações de CPU/RAM a cada 2 segundos
      Timer.periodic(Duration(seconds: 2), (timer) {
        if (socket.connected) {
          socket.emit('request_stats');
        }
      });
    });

    // Quando o Python responde 'receive_stats', o Flutter "ouve" aqui
    socket.on('receive_stats', (data) {
      _statsController.add(data);
    });

    socket.onDisconnect((_) => print('Desconectado do servidor'));
  }

  void sendMouseMove(double dx, double dy) {
    socket.emit('mouse_move', {'dx': dx, 'dy': dy});
  }

  void sendMouseClick(String button) {
    socket.emit('mouse_click', {'button': button});
  }

  void sendText(String text) {
    socket.emit('keyboard_type', {'text': text});
  }

  void sendSpecialKey(String key) {
    socket.emit('keyboard_key', {'key': key});
  }

  void sendShutdown(String token, int tempoSegundos) {
    socket.emit('exec_shutdown', {
      'token': token,
      'tempo': tempoSegundos,
    });
  }

  void sendAbortShutdown() {
    socket.emit('abortar_desligamento');
  }

  void sendBrightness(String acao) {
    socket.emit('controle_brilho', {'acao': acao});
  }

  void sendVolume(String acao) {
    socket.emit('controle_volume', {'acao': acao});
  }

  void dispose() {
    _statsController.close();
    socket.dispose();
  }
}