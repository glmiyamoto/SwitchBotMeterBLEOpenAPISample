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
        /// Communication Service UUID
        static let uuid = CBUUID(string: "cba20d00-224d-11e6-9fb8-0002a5d5c51b")

        // UUID list of scan RSP
        static let rspUUIDs: [CBUUID] = [
            uuid,
            CBUUID(string: "000D"),
            CBUUID(string: "FEE7"),
            CBUUID(string: "FD3D")
        ]
    }

    enum Characteristic {
        /// RX characteristic UUID of the message from the Terminal to the Device. Vendor UUID types start at this index (128-bit).
        ///
        /// Char Attribute :RW
        /// Char Properties: notify
        static let rxUUID = CBUUID(string: "cba20002-224d-11e6-9fb8-0002a5d5c51b")
        
        /// TX  characteristic UUID of the message from the Device to the Terminal. Vendor UUID types start at this index (128-bit).
        /// Char Attribute :RW
        static let txUUID = CBUUID(string: "cba20003-224d-11e6-9fb8-0002a5d5c51b")
    }

    static let shared = SwitchBotMeterBluetoothManager()

    private var centralManager: CBCentralManager!

    private var peripherals = Set<CBPeripheral>()

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

        peripherals.forEach { peripheral in
            centralManager.cancelPeripheralConnection(peripheral)
        }
        peripherals = []
    }

    func connect() {
        guard let peripheral = peripherals.first else { return }
        peripheral.delegate = self
        centralManager.connect(peripheral)
    }

    private func scanForPeripherals() {
        guard !centralManager.isScanning else { return }
        print("Scanning for bluetooth service.")
        centralManager.scanForPeripherals(
            withServices: Service.rspUUIDs,
            options: nil
        )
    }

    private func update(serviceData: ServiceData) {
        if let _battery = serviceData.battery {
            battery = _battery
        }

        if let _humidity = serviceData.humidity {
            humidity = _humidity
        }

        if let _temperature = serviceData.temperature {
            temperature = _temperature
        }
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
                update(serviceData: serviceData)
                break
            }
        }

        if let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
           let serviceData = ServiceData(data: data) {
            print("Manufacture data: \(data.map({ String(format:"%02x ", $0) }).joined())")
            update(serviceData: serviceData)
        }

        peripherals.insert(peripheral)
    }
}

extension SwitchBotMeterBluetoothManager: CBPeripheralDelegate {

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Did connect peripheral: \(peripheral.identifier)")
        // Discover for communication service
        peripheral.discoverServices([Service.uuid])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Did fail to connect peripheral: \(peripheral.identifier); error: \(error)")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Did disconnect peripheral: \(peripheral.identifier); error: \(error)")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Did discover services; error: \(error)")

        guard let service = peripheral.services?.first(where: { $0.uuid.isEqual(Service.uuid) })
        else {
            print("Service not found -> peripheral=\(peripheral)")
            peripherals.remove(peripheral)
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }

        print("Service found -> peripheral=\(peripheral)")
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("Did discover characteristics for \(service.uuid); error: \(error)")

        guard service.uuid.isEqual(Service.uuid) else { return }
        if let characteristic = (service.characteristics ?? [])
            .first(where: { $0.uuid.isEqual(Characteristic.txUUID) }) {
            peripheral.setNotifyValue(true, for: characteristic)
        }

        if let characteristic = (service.characteristics ?? [])
            .first(where: { $0.uuid.isEqual(Characteristic.rxUUID) }) {
            // Sending "Read the Display Mode and Value of the Meter" command
            // ref: https://github.com/OpenWonderLabs/SwitchBotAPI-BLE/blob/latest/devicetypes/meter.md#0x31-read-the-display-mode-and-value-of-the-meter
            peripheral.writeValue(Data([0x57, 0x0F, 0x31, 0x00]), for: characteristic, type: .withoutResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("Did update notification state for \(characteristic.uuid); notifying: \(characteristic.isNotifying); error: \(error)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Did update value for \(characteristic.uuid); error: \(error)")

        guard let characteristic = peripheral.services?
            .filter({ $0.uuid.isEqual(Service.uuid) })
            .flatMap({ $0.characteristics ?? [] })
            .first(where: { $0.uuid.isEqual(Characteristic.txUUID) }),
              let data = characteristic.value,
              let meter = Meter(data: data)
        else { return }
        print("Characteristic data: \(data.map({ String(format:"%02x ", $0) }).joined())")
        humidity = meter.humidity
        temperature = meter.temperature

        // Disconnect peripheral to release
        centralManager.cancelPeripheralConnection(peripheral)
    }
}
