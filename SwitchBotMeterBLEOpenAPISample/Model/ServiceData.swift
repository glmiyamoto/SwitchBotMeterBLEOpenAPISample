//
//  ServiceData.swift
//  SwitchBotMeterBLEOpenAPISample
//
//  Created by Gustavo Luis Miyamoto on 2024/05/14.
//

import Foundation

struct ServiceData {
    private let meter: Meter?

    /// Battery in percent
    let battery: Int?

    /// Humidity in percent
    var humidity: Int? {
        meter?.humidity
    }

    /// Temperature in celsius
    var temperature: Double? {
        meter?.temperature
    }

    init?(data: Data) {
        switch data.count {
        case 3: // from service data (compact version)
            meter = nil
        case 6: // from service data
            meter = Meter(data: data, humidityByteIndex: 5, temperatureByteIndex: 3)
        case 14: // from manufacture data
            meter = Meter(data: data, humidityByteIndex: 12, temperatureByteIndex: 10)
            battery = nil
            return
        default:
            return nil
        }

        // Bit[6:0] - Remaining Battery 0~100%
        battery = data[safe: 2].flatMap { Int($0 & 0x7F) }
    }
}
