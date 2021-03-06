//
// ApplicationController.swift
// Apple Juice
// https://github.com/raphaelhanneken/apple-juice
//

import Cocoa
import LaunchAtLogin

final class ApplicationController: NSObject {

    /// Holds a weak reference to the application menu.
    @IBOutlet weak var applicationMenu: NSMenu!
    /// Holds a weak reference to the charging status menu item.
    @IBOutlet weak var currentCharge: NSMenuItem!

    /// The status bar item.
    private var statusItem: StatusBarItem?
    /// An abstraction to the battery IO service
    private var battery: BatteryService!

    @objc dynamic var launchAtLogin = LaunchAtLogin.kvo

    override init() {
        super.init()

        do {
            battery = try BatteryService()
            statusItem = StatusBarItem(forBattery: battery,
                                       withAction: #selector(ApplicationController.displayAppMenu(_:)),
                                       forTarget: self)
            statusItem?.update(batteryInfo: battery)
            registerAsObserver()
        } catch {
            statusItem = StatusBarItem(
                forError: error as? BatteryError,
                withAction: #selector(ApplicationController.displayAppMenu(_:)),
                forTarget: self)
        }
    }

    ///  This message is sent to the receiver when the value at the specified key path relative to the given object
    ///  has changed. The receiver must be registered as an observer for the specified keyPath and object.
    ///
    ///  - parameter keyPath: The key path, relative to object, to the value that has changed.
    ///  - parameter object: The source object of the key path.
    ///  - parameter change: A dictionary that describes the changes that have been made to
    ///                      the value of the property at the key path keyPath relative to object.
    ///                      Entries are described in Change Dictionary Keys.
    ///  - parameter context: The value that was provided when the receiver was registered to receive key-value
    ///                       observation notifications.
    override func observeValue(forKeyPath _: String?,
                               of _: Any?,
                               change _: [NSKeyValueChangeKey: Any]?,
                               context _: UnsafeMutableRawPointer?) {
        statusItem?.update(batteryInfo: battery)
    }

    ///  This message is sent to the receiver, when a powerSourceChanged message was posted. The receiver
    ///  must be registered as an observer for powerSourceChangedNotification's.
    ///
    ///  - parameter sender: The object that posted powerSourceChanged message.
    @objc public func powerSourceChanged(_: AnyObject) {
        statusItem?.update(batteryInfo: battery)

        if let notification = StatusNotification(forState: battery.state) {
            notification.postNotification()
        }
    }

    ///  Displays the application menu when the user clicks the menu bar item.
    ///
    ///  - parameter sender: The object that sent the message.
    @objc public func displayAppMenu(_: AnyObject) {
        updateMenuItems({
            statusItem?.popUpMenu(applicationMenu)
        })
    }

    ///  Open the energy saver preference pane.
    ///
    ///  - parameter sender: The menu item object that sent the message.
    @IBAction public func energySaverPreferences(_: NSMenuItem) {
        NSWorkspace.shared.openFile("/System/Library/PreferencePanes/EnergySaver.prefPane")
    }

    ///  Updates informations within the application menu.
    ///
    ///  - parameter completionHandler: A callback function, to be called when a menu item was updated.
    private func updateMenuItems(_ completionHandler: () -> Void) {
        guard let capacity = battery.capacity,
              let charge = battery.charge,
              let amperage = battery.amperage
        else {
            return
        }

        var timeRemaining = battery.timeRemainingFormatted
        if UserPreferences.showTime {
            timeRemaining = battery.percentageFormatted
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 3.0

        let powerSource = NSMutableAttributedString(
            string: "\(NSLocalizedString("Power Source", comment: "")) \(battery.powerSource)\n",
            attributes: [.font: NSFont.menuFont(ofSize: 13.0), .paragraphStyle: paragraphStyle])

        let details = NSAttributedString(
            string: "\(timeRemaining) \(charge) / \(capacity) mAh (\(amperage) mA)",
            attributes: [.font: NSFont.menuFont(ofSize: 12.0)])

        powerSource.append(details)

        currentCharge.attributedTitle = powerSource
        completionHandler()
    }

    /// Registers the ApplicationController as observer for power source and user preference changes
    private func registerAsObserver() {
        UserDefaults
            .standard
            .addObserver(self, forKeyPath: PreferenceKey.showTime.rawValue, options: .new, context: nil)

        UserDefaults
            .standard
            .addObserver(self, forKeyPath: PreferenceKey.hideMenubarInfo.rawValue, options: .new, context: nil)

        UserDefaults
            .standard
            .addObserver(self, forKeyPath: PreferenceKey.hideBatteryIcon.rawValue, options: .new, context: nil)

        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(ApplicationController.powerSourceChanged(_:)),
                         name: NSNotification.Name(rawValue: powerSourceChangedNotification),
                         object: nil)
    }

}
