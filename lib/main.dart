import 'package:flutter/material.dart';
import 'socket_service.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'secrets.dart'; 

void main() => runApp(MaterialApp(
  title: 'Control Sentinel',
  theme: ThemeData(
    brightness: Brightness.dark,
    primaryColor: Color(0xFF3B82F6), // Azul Elétrico
    scaffoldBackgroundColor: Color(0xFF0F172A), // Slate Profundo
    cardColor: Color(0xFF1E293B), // Cinza Azulado para os cards
    fontFamily: 'Roboto', // Ou use GoogleFonts se preferir
  ),
  debugShowCheckedModeBanner: false,

  home: EcoHostDashboard(),
));

class EcoHostDashboard extends StatefulWidget {
  @override
  _EcoHostDashboardState createState() => _EcoHostDashboardState();
}

class _EcoHostDashboardState extends State<EcoHostDashboard> {

  final LocalAuthentication auth = LocalAuthentication();
  List<FlSpot> cpuPoints = [];
  List<FlSpot> ramPoints = [];
  int counter = 0; // Serve como o eixo X (tempo)
  Timer? _countdownTimer;
  int _segundosRestantes = 0;
  bool _isDesligamentoAgendado = false;
  final service = SocketService();
  final TextEditingController _tecladoController = TextEditingController();

  Future<void> _autenticarEProsseguir() async {
    try {
      bool autenticado = await auth.authenticate(
        localizedReason: 'Autentique-se para comandos críticos',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (autenticado) {
        _confirmarAcao(context);
      }
    } on PlatformException catch (e) {
      print(e);
      // Se o celular não tiver biometria, prossegue direto (fallback)
      _confirmarAcao(context);
    }
  }

  void _abrirTecladoRemoto(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Teclado Remoto"),
        content: TextField(
          controller: _tecladoController,
          autofocus: true, // Abre o teclado do telemóvel automaticamente
          decoration: InputDecoration(hintText: "Digite algo para enviar ao PC..."),
          onSubmitted: (text) {
            service.sendText(text);
            service.sendSpecialKey('enter'); // Envia e dá 'Enter' no PC
            _tecladoController.clear();
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
              onPressed: () {
                service.sendText(_tecladoController.text);
                _tecladoController.clear();
              },
              child: Text("Enviar Texto")
          ),
        ],
      ),
    );
  }
  
  final String ipDoComputador = Secrets.ipComputador;

  @override
  void initState() {
    super.initState();
    service.connect(ipDoComputador);

    // Ouvindo o stream para alimentar o gráfico
    service.statsStream.listen((data) {
      if (mounted) {
        setState(() {
          // Usamos double.tryParse para evitar que o app feche se houver erro nos dados
          double cpu = double.tryParse(data['cpu_uso']?.toString() ?? '0') ?? 0;
          double ram = double.tryParse(data['ram_uso']?.toString() ?? '0') ?? 0;

          cpuPoints.add(FlSpot(counter.toDouble(), cpu));
          ramPoints.add(FlSpot(counter.toDouble(), ram));

          if (cpuPoints.length > 30) {
            cpuPoints.removeAt(0);
            ramPoints.removeAt(0);
          }
          counter++;
        });
      }
    });
  }

  String _formatarTempo(int segundos) {
    int min = segundos ~/ 60;
    int seg = segundos % 60;
    return "${min.toString().padLeft(2, '0')}:${seg.toString().padLeft(2, '0')}";
  }

  Widget _buildLiveChart(String title, List<FlSpot> points, Color color) {
    return Container(
      height: 150,
      padding: EdgeInsets.all(10),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false), // Remove legendas para ficar clean
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 100, // Escala de 0 a 100%
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true,
                  color: color.withOpacity(0.2)
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Control Sentinel")),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: service.statsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: Text("Aguardando conexão com o PC..."));
          }

          var stats = snapshot.data!;
          // SingleChildScrollView evita o erro de "Bottom Overflow"
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [


                  Text("Tempo de Atividade: ${stats['uptime']}"),
                  SizedBox(height: 10),
                  _buildLiveChart("Histórico CPU", cpuPoints, Colors.blue), // Gráfico aqui
                  _buildMetricCard("Uso de CPU", "${stats['cpu_uso']}%", Icons.speed, Colors.blue),

                  _buildLiveChart("Histórico RAM", ramPoints, Colors.purple), // Gráfico aqui
                  _buildMetricCard("Uso de RAM", "${stats['ram_uso']}%", Icons.memory, Colors.purple),



                  // Touchpad
                  Container(
                    height: 300,
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E293B).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.05),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          // Efeito de gradiente de fundo
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 1.0,
                                  colors: [
                                    Colors.blueAccent.withOpacity(0.05),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onPanUpdate: (details) {
                              HapticFeedback.selectionClick(); // Vibração leve ao mover
                              service.sendMouseMove(details.delta.dx, details.delta.dy);
                            },
                            onTap: () {
                              HapticFeedback.lightImpact();
                              service.sendMouseClick('left');
                            },
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mouse, size: 60, color: Colors.blueAccent.withOpacity(0.5)),
                                  SizedBox(height: 10),
                                  Text("PAINEL DE PRECISÃO",
                                      style: TextStyle(
                                        color: Colors.blueAccent.withOpacity(0.5),
                                        letterSpacing: 2,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // --- SEÇÃO DE BRILHO ---
                  _buildSelectionHeader("Iluminação do Monitor"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: Icons.brightness_low,
                        color: Colors.orangeAccent,
                        label: "DIMINUIR",
                        onPressed: () { service.sendBrightness('diminuir');
                        print("Botão de brilho pressionado!");
                          },
                      ),
                      _buildControlButton(
                        icon: Icons.brightness_high,
                        color: Colors.orangeAccent,
                        label: "AUMENTAR",
                        onPressed: () { service.sendBrightness('aumentar');
                        print("Botão de brilho pressionado!");
                          },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20), // Espaçamento entre seções

                  // --- SEÇÃO DE VOLUME ---
                  _buildSelectionHeader("Áudio do Sistema"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: Icons.volume_down,
                        color: Colors.cyanAccent,
                        label: "BAIXAR",
                        onPressed: () => service.sendVolume('diminuir'),
                      ),
                      _buildControlButton(
                        icon: Icons.volume_off,
                        color: Colors.redAccent,
                        label: "MUDO",
                        onPressed: () => service.sendVolume('mudo'),
                      ),
                      _buildControlButton(
                        icon: Icons.volume_up,
                        color: Colors.cyanAccent,
                        label: "ELEVADO",
                        onPressed: () => service.sendVolume('aumentar'),
                      ),
                    ],
                  ),
                  Divider(color: Colors.white24),




                  _buildSelectionHeader("Gestão de Energia"),
                  const SizedBox(height: 10),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _isDesligamentoAgendado
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.redAccent.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDesligamentoAgendado
                            ? Colors.orange[900]
                            : const Color(0xFF7F1D1D), // Vermelho escuro premium
                        minimumSize: const Size(double.infinity, 80),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _isDesligamentoAgendado
                                ? Colors.orange
                                : Colors.redAccent.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (_isDesligamentoAgendado) {
                          // Se já estiver agendado, chamamos a função de cancelar
                          _cancelarDesligamento();
                        } else {
                          // Se não estiver agendado, seguimos para a autenticação/agendamento
                          _autenticarEProsseguir();
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isDesligamentoAgendado ? Icons.timer : Icons.power_settings_new,
                            color: Colors.white,
                            size: 30,
                          ),
                          const SizedBox(width: 15),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isDesligamentoAgendado ? "CANCELAR AGENDAMENTO" : "ENCERRAR SISTEMA",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                              if (_isDesligamentoAgendado)
                                Text(
                                  "PC desligará em: ${_formatarTempo(_segundosRestantes)}",
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () => _abrirTecladoRemoto(context),
        child: Icon(Icons.keyboard, color: Colors.white),
      ),
    );
  } // Fim do build

  // Métodos auxiliares permanecem DENTRO da classe _EcoHostDashboardState

  // Definição 1: O Cabeçalho
  Widget _buildSelectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              )),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Colors.blueAccent.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact(); // Feedback tátil essencial para QA
              onPressed();
            },
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              )),
          SizedBox(width: 10),
          Expanded(child: Divider(color: Colors.blueAccent.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B), // Cor base do card
            Color(0xFF334155).withOpacity(0.5), // Brilho sutil
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(15),
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: TextStyle(color: Colors.blueGrey[200], fontSize: 14)),
        trailing: Text(value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            )),
      ),
    );
  }

  // 1. O PRIMEIRO DIÁLOGO (Escolha: Agora ou Agendar)
  void _confirmarAcao(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obriga o usuário a escolher uma opção
      builder: (ctx) => AlertDialog(
        title: Text("Desligar Computador"),
        content: Text("Escolha o tipo de desligamento:"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Fecha este diálogo
              _executarDesligamento(0); // Desliga agora
            },
            child: Text("DESLIGAR AGORA", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Fecha este diálogo antes de abrir o próximo
              _agendarDesligamento(context); // Chama o próximo
            },
            child: Text("AGENDAR..."),
          ),
        ],
      ),
    );
  }

// 2. O SEGUNDO DIÁLOGO (Definir Minutos)
  void _agendarDesligamento(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Agendar Desligamento"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Em quantos minutos?",
            hintText: "Ex: 60",
            suffixText: "min",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("CANCELAR")
          ),
          ElevatedButton(
            onPressed: () {
              int? minutos = int.tryParse(controller.text);
              if (minutos != null && minutos > 0) {
                // Primeiro: Executa a lógica
                _executarDesligamento(minutos * 60);
                // Segundo: Fecha o diálogo
                Navigator.pop(ctx);
              }
            },
            child: Text("CONFIRMAR AGENDAMENTO"), // Nome diferente para evitar confusão
          ),
        ],
      ),
    );
  }


  void _executarDesligamento(int segundos) {
    service.sendShutdown(Secrets.tokenAutenticacao, segundos);

    if (segundos > 0) {
      setState(() {
        _segundosRestantes = segundos;
        _isDesligamentoAgendado = true;
      });
      _iniciarCronometro();
    } else {
      // Se for imediato, apenas envia o comando
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Desligando agora..."), backgroundColor: Colors.red),
      );
    }
  }

  void _iniciarCronometro() {
    _countdownTimer?.cancel(); // Cancela qualquer timer anterior por segurança
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 0) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        _pararCronometro();
      }
    });
  }

  void _cancelarDesligamento() {
    service.sendAbortShutdown();
    _pararCronometro();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Desligamento cancelado!"), backgroundColor: Colors.green),
    );
  }

  void _pararCronometro() {
    _countdownTimer?.cancel();
    setState(() {
      _isDesligamentoAgendado = false;
      _segundosRestantes = 0;
    });
  }

// Importante para não vazar memória
  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tecladoController.dispose();
    super.dispose();
  }
} // Fim da classe



