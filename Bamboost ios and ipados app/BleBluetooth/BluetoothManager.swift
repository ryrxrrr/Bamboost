import CoreBluetooth
import SwiftUI
import Combine

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var arduinoPeripheral: CBPeripheral?
    
    @Published var receivedMessage: String = ""
    
    let arduinoServiceUUID = CBUUID(string: "0000ABCD-0000-1000-8000-00805F9B34FB")
    let arduinoOutputCharacteristicUUID = CBUUID(string: "0000ABCE-0000-1000-8000-00805F9B34FB")
    let arduinoInputCharacteristicUUID = CBUUID(string: "0000ABCF-0000-1000-8000-00805F9B34FB")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [arduinoServiceUUID], options: nil)
        } else {
            print("Bluetooth is not available.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        arduinoPeripheral = peripheral
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Arduino device")")
        peripheral.delegate = self
        peripheral.discoverServices([arduinoServiceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([arduinoOutputCharacteristicUUID, arduinoInputCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == arduinoOutputCharacteristicUUID || characteristic.uuid == arduinoInputCharacteristicUUID {
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value, characteristic.uuid == arduinoOutputCharacteristicUUID {
            let intValue = value.withUnsafeBytes { $0.load(as: Int32.self) }
            DispatchQueue.main.async {
                self.receivedMessage = String(intValue)
                print("Received message from Arduino: \(intValue)")
            }
        }
    }
    
    func sendMessageToArduino(_ message: Int) {
        guard let arduinoPeripheral = arduinoPeripheral,
              let service = arduinoPeripheral.services?.first(where: { $0.uuid == arduinoServiceUUID }),
              let characteristic = service.characteristics?.first(where: { $0.uuid == arduinoInputCharacteristicUUID }) else {
            print("Device not ready for sending messages.")
            return
        }

        let data = Data([UInt8(message & 0xff), UInt8((message >> 8) & 0xff)])
        arduinoPeripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}
