import SwiftUI

// 定义VisualEffectBlur，用于在SwiftUI中实现磨砂效果
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

struct ContentView: View {
    @ObservedObject var bluetoothManager = BluetoothManager()
    @State private var lightIsOn: Bool = false
    @State private var selectedTimer: Double = 5
    let timerOptions = [5.0, 15.0, 30.0, 60.0, 120.0]
    @State private var wavePhase = 0.0

    var body: some View {
        VStack {
            GroupBox(label: Label("Soil Moisture", systemImage: "drop.fill")) {
                ZStack {
                    GeometryReader { geometry in
                        let moistureLevel = Double(bluetoothManager.receivedMessage) ?? 0
                        let waterHeight = geometry.size.height * CGFloat(moistureLevel) / 100
                        
                        if moistureLevel > 0 {
                            WaveShape(phase: wavePhase)
                                .fill(Color.blue.opacity(0.5))
                                .frame(width: geometry.size.width, height: waterHeight)
                                .offset(y: geometry.size.height - waterHeight)
                                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: wavePhase)
                        }
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    
                    ZStack {
                        VisualEffectBlur(blurStyle: .systemThinMaterialLight) // 不作为尾随闭包传递内容
                        Text("\(bluetoothManager.receivedMessage)%")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 0, height: 0)//土壤湿度数字大小和框
                    .cornerRadius(10)
                    .position(x: 200, y: -17)
                }
            }
            .padding()
            .frame(height: 120)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    wavePhase -= 360
                }
            }

            GroupBox(label: Label("Controls", systemImage: "switch.2")) {
                VStack {
                    Toggle(isOn: $lightIsOn) {
                        Text("Light Control")
                    }
                    .padding()
                    .onChange(of: lightIsOn) { newValue in
                        bluetoothManager.sendMessageToArduino(newValue ? 1 : 2)
                    }

                    Slider(value: $selectedTimer, in: timerOptions.first!...timerOptions.last!, step: 1)
                        .padding()
                        .onChange(of: selectedTimer) { newValue in
                            selectedTimer = timerOptions.min(by: { abs($0 - newValue) < abs($1 - newValue) }) ?? selectedTimer
                        }

                    Text("Timer: \(Int(selectedTimer)) min")
                        .padding()

                    Button("Set Timer") {
                        bluetoothManager.sendMessageToArduino(Int(selectedTimer))
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()

            Link(destination: URL(string: "https://lilac-corn-19n2jt.mysxl.cn")!) {
                Image("BambooImage")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(radius: 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill the entire screen

        // 根据灯光状态改变背景色
        .background(lightIsOn ? Color.white : Color.black.opacity(0.5))
    }
}

struct WaveShape: Shape {
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: rect.midY))
        for x in stride(from: 0, through: rect.width, by: 1) {
            let relativeX = x / rect.width
            let sineValue = sin(relativeX * 2 * .pi + CGFloat(phase))
            let y = rect.midY - 10 * sineValue
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
