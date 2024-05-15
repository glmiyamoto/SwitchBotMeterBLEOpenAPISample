//
//  ServiceData.swift
//  SwitchBotMeterBLEOpenAPISample
//
//  Created by Gustavo Luis Miyamoto on 2024/05/14.
//

import Foundation

struct ServiceData {
    private let meter: Meter

    /// Battery in percent
    let battery: Int

    /// Humidity in percent
    var humidity: Int {
        meter.humidity
    }

    /// Temperature in celsius
    var temperature: Double {
        meter.temperature
    }

    init?(data: Data) {
        let distanceByteIndex: Int
        let _meter: Meter?
        switch data.count {
        case 6: // from service data
            distanceByteIndex = 2
            _meter = Meter(data: data, humidityByteIndex: 5, temperatureByteIndex: 3)
        case 14: // from manufacture data
            distanceByteIndex = 5
            _meter = Meter(data: data, humidityByteIndex: 12, temperatureByteIndex: 10)
        default:
            return nil
        }

        guard let _meter,
              let distanceByte = data[safe: distanceByteIndex] else { return nil }
        meter = _meter

        // Bit[6:0] - Remaining Battery 0~100%
        battery = Int(distanceByte & 0x7F)
    }
}
