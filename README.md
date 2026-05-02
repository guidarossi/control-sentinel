### Control Sentinel
Control Sentinel is a hardware monitoring and remote automation system. It allows you to track your PC's performance and execute system commands directly from a mobile device.

### ✨ Features
- Real-time Monitoring: View live CPU, RAM, and temperature metrics via a dynamic dashboard.
- Remote Commands: Shutdown or restart your computer remotely with immediate or scheduled timers.
- System Control: Remotely manage mouse movements, clicks, text input, and system volume.
- Security: Access is protected by biometric authentication (Fingerprint/Face ID) and token-based validation.

### 🛠️ Tech Stack
- Mobile App: Built with Flutter and Dart.
- Backend Server: Powered by Python using Flask and Socket.io for real-time communication.
- System Integration: Uses psutil for hardware data and PyAutoGUI for remote input simulation.

### 🚀 Getting Started1.
 1. Server Setup (PC)
 Install the required Python libraries:
 `pip install -r pc_server/requirements.txt`

 Run the backend:
 `python server.py`

2. Mobile App Setup
Install Flutter dependencies:
`flutter pub get`

Run the application:
`flutter run`
