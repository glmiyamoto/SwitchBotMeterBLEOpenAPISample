//
//  ContentView.swift
//  SwitchBotMeterBLEOpenAPISample
//
//  Created by Gustavo Luis Miyamoto on 2024/05/09.
//

import SwiftUI

struct ContentView: View {

    @StateObject var binder = ContentViewBinder()

    var body: some View {
        VStack {
            HStack {
                Text("Temperature: ")
                Text(binder.temperature.flatMap({ String($0) + "°C" }) ?? "-")
                Spacer()
            }
            HStack {
                Text("Humidity: ")
                Text(binder.humidity.flatMap({ String($0) + "%" }) ?? "-")
                Spacer()
            }
            HStack {
                Text("Battery: ")
                Text(binder.battery.flatMap({ String($0) + "%" }) ?? "-")
                Spacer()
            }
            Spacer()
        }
        .padding()
    }
}

final class ContentViewBinder: ObservableObject {
    private let manager = SwitchBotMeterBluetoothManager.shared
    private var observations = [NSKeyValueObservation]()

    /// Battery in percent
    @Published private(set) var battery: Int?
    /// Humidity in percent
    @Published private(set) var humidity: Int?
    /// Temperature in celsius
    @Published private(set) var temperature: Double?

    init() {
        observations = [
            manager.observe(\.battery, options: [.new, .old]) { [weak self] _, value in
                self?.battery = value.newValue
            },
            manager.observe(\.humidity, options: [.new, .old]) { [weak self] _, value in
                self?.humidity = value.newValue
            },
            manager.observe(\.temperature, options: [.new, .old]) { [weak self] _, value in
                self?.temperature = value.newValue
            }
        ]
    }

    deinit {
        observations.forEach({ $0.invalidate() })
        observations = []
    }
}

#Preview {
    ContentView()
}
