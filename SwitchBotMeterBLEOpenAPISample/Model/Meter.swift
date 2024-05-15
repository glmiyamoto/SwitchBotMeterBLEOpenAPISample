//
//  Meter.swift
//  SwitchBotMeterBLEOpenAPISample
//
//  Created by Gustavo Luis Miyamoto on 2024/05/14.
//

import Foundation

struct Meter: MeterBLEAPIObject {
    /// Humidity in percent
    let humidity: Int
    /// Temperature in celsius
    let temperature: Double

    init?(data: Data) {
        guard data.count == 4 else { return nil }
        self.init(data: data, humidityByteIndex: 3, temperatureByteIndex: 1)
    }

    init?(data: Data, humidityByteIndex hbi: Int, temperatureByteIndex tbi: Int) {
        guard let humidityByte = data[safe: hbi],
              let temperatureByte1 = data[safe: tbi],
              let temperatureByte2 = data[safe: tbi + 1] else { return nil }
        humidity = Int(humidityByte & 0x7F)

        // Bit[7] – Positive/Negative temperature flag
        // 0: subzero temperature
        // 1: temperature above zero
        let multiplier: Double = (temperatureByte2 & 0x80) > 0 ? 1.0 : -1.0
        // Bit[3:0] – Decimals of the Temperature
        let decimalsOfTemperature = Double(temperatureByte1 & 0x0F) * 0.1
        // Bit[6:0] – Integers of the Temperature 000 0000 – 111 1111: 0~127 °C
        let integersOfTemperature = Double(temperatureByte2 & 0x7F)
        temperature = (integersOfTemperature + decimalsOfTemperature) * multiplier
    }
}
