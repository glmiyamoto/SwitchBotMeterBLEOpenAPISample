//
//  BluetoothManager.swift
//  SwitchBotMeterBLEOpenAPISample
//
//  Created by Gustavo Luis Miyamoto on 2024/05/09.
//

import CoreBluetooth

final class SwitchBotMeterBluetoothManager: NSObject {
    enum Device: String, CaseIterable {
        case bot = "Bot"
        case remote = "Remote"
        case hub = "Hub"
        case woSensorTH = "WoSensorTH"
        case woIOSensorTH = "WoIOSensorTH"
    }

    enum Service {
        // UUID list of scan RSP
        static let rspUUIDs: [CBUUID] = [
            CBUUID(string: "000D"),
            CBUUID(string: "FD3D")
        ]
    }

    static let shared = SwitchBotMeterBluetoothManager()

    private var centralManager: CBCentralManager!

    /// Battery in percent
    @objc dynamic var battery: Int = .max
    /// Humidity in percent
    @objc dynamic var humidity: Int = .max
    /// Temperature in celsius
    @objc dynamic var temperature: Double = .greatestFiniteMagnitude

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    deinit {
        if centralManager.isScanning {
            centralManager.stopScan()
        }
    }

    private func scanForPeripherals() {
        guard !centralManager.isScanning else { return }
        print("Scanning for bluetooth service.")
        centralManager.scanForPeripherals(
            withServices: Service.rspUUIDs,
            options: nil
        )
    }
}

extension SwitchBotMeterBluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Bluetooth is powered on, start scanning for devices
            print("Bluetooth is available.")
            scanForPeripherals()
        } else {
            // Bluetooth is not available or powered off
            print("Bluetooth is not available.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // A peripheral device has been discovered, you can connect to it here
        guard let name = peripheral.name, Device.allCases.contains(where: { $0.rawValue == name }) else { return }
        print("Discovered peripheral: \(name)")

        if let dic = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            for key in dic.keys {
                guard let data = dic[key] else { continue }
                print("ServiceData[\(key.uuidString)]: \(data.map({ String(format:"%02x ", $0) }).joined())")

                guard let serviceData = ServiceData(data: data) else { continue }
                battery = serviceData.battery
                humidity = serviceData.humidity
                temperature = serviceData.temperature
                break
            }
        }

        if let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
           let serviceData = ServiceData(data: data) {
            print("Manufacture data: \(data.map({ String(format:"%02x ", $0) }).joined())")
            battery = serviceData.battery
            humidity = serviceData.humidity
            temperature = serviceData.temperature
        }
    }
}
