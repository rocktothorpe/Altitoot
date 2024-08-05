//
//  ContentView.swift
//  Altitoot
//
//  Created by Raquel Bonilla on 8/2/24.
//

import AudioToolbox
import AVFoundation
import CoreLocation
import SwiftUI


public var glassLight10: Color { .init(hex: "#FFFFFF").opacity(0.1) }

class AltitudeManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    @Published var altitude: Double = 0.0
    @Published var threshold: Double = 0 // Threshold in feet
    @Published var shouldBeep: Bool = true
    @Published var threshholdType: ThreshholdType = .below
    @Published var thresholdViolated: Bool = false
    @Published var sound: SoundType = .danger
    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        setupLocationManager()
        configureAudioSession()
        loadAudioFile()
    }

    public func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestAlwaysAuthorization()
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false
        locationManager?.startUpdatingLocation()
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func loadAudioFile() {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a") else {
            print("Audio file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error loading audio file: \(error)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        altitude = location.altitude * 3.28084 // altitude in feet
        print("altitude is \(altitude)")
        checkThreshold()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
    }

    func checkThreshold() {
        switch threshholdType {
        case .over:
            if altitude > threshold {
                playSound()
            }
        case .below:
            if altitude < threshold {
                playSound()
            }
        }
    }

    private func playSound() {
        if shouldBeep {
            audioPlayer?.play()
        }
    }
}

public enum ThreshholdType: String, CaseIterable {
    case over
    case below
}

public enum SoundType: String, CaseIterable {
    case alarm
    case danger
}


struct ContentView: View {
    @StateObject private var altitudeManager = AltitudeManager()
    @State var thresholdString: String = ""
    let fontSizeLarge: CGFloat = 32
    let fontSizeMed: CGFloat = 24

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 32) {
                Spacer()
                Text("Altitude: \(altitudeManager.altitude.rounded(), specifier: "%.f") feet")
                    .font(.system(size: fontSizeLarge, weight: .regular, design: .default))

                Toggle(isOn: $altitudeManager.shouldBeep) {
                    Text("Toggle Beep")
                        .font(.system(size: fontSizeMed, weight: .regular, design: .default))
                }
                Text("Current Threshold: \(altitudeManager.threshold, specifier: "%.f")")
                    .font(.system(size: fontSizeMed, weight: .regular, design: .default))
                TextField("Enter threshold value", text: $thresholdString)
                    .keyboardType(.numberPad)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: thresholdString) { _, newVal in
                        if let num = Int(newVal) {
                            altitudeManager.threshold = Double(num)
                        }
                    }

                HStack(spacing: 8) {
                    Text("Sound:")
                        .font(.system(size: fontSizeMed, weight: .regular, design: .default))
                    Picker("Select Sound", selection: $altitudeManager.sound) {
                        ForEach(SoundType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }

                HStack {
                    Text("Threshhold Type")
                    Picker("Select Threshold", selection: $altitudeManager.threshholdType) {
                        ForEach(ThreshholdType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(height: 50)
                }

                Spacer()
            }
            Spacer()
        }
        .background(.black)
        .padding(24)
        .onAppear {
            altitudeManager.setupLocationManager()
            altitudeManager.locationManager?.requestAlwaysAuthorization()
        }
        .onChange(of: altitudeManager.sound) { _, _ in
            altitudeManager.loadAudioFile()
        }
        .onTapGesture {
            self.hideKeyboard()
        }
    }
}

extension View {
    public func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
