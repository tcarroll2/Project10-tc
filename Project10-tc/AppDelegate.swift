//
//  AppDelegate.swift
//  Project10-tc
//
//  Created by Thomas Carroll on 4/23/20.
//  Copyright © 2020 Thomas Carroll. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var feed: JSON?
    var displayMode = 0
    var updateDisplayTimer: Timer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let defaultSettings = ["latitude": "30.808114", "longitude": "-88.071143", "apiKey": "", "statusBarOption": "-1", "units": "1"]
        UserDefaults.standard.register(defaults: defaultSettings)
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(loadSettings), name: Notification.Name("SettingsChanged"), object: nil)
        statusItem.button?.title = "Fetching..."
        statusItem.menu = NSMenu()
        addConfigurationMenuItem()
        loadSettings()
    }

    @objc func loadSettings() {
        fetchFeed()
        displayMode = UserDefaults.standard.integer(forKey: "statusBarOption")
        configureUpdateDisplayTimer()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func addConfigurationMenuItem() {
        let separator = NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: "")
        statusItem.menu?.addItem(separator)
    }
    
    @objc func showSettings(_ sender: NSMenuItem) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        guard let vc = storyboard.instantiateController(withIdentifier: "ViewController") as? ViewController else { return }
        let popoverView = NSPopover()
        popoverView.contentViewController = vc
        popoverView.behavior = .transient
        popoverView.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .maxY)
    }
    
    func refreshSubmenuItems() {
        guard let feed = feed else { return }
        statusItem.menu?.removeAllItems()
        for forecast in feed["hourly"].arrayValue.prefix(10) {
            let date = Date(timeIntervalSince1970: forecast["dt"].doubleValue)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let formattedDate = formatter.string(from: date)
            let summary = forecast["weather"][0]["description"].stringValue
            let temperature = forecast["temp"].intValue
            let title = "\(formattedDate): \(summary) (\(temperature)°)"
            let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            statusItem.menu?.addItem(menuItem)
        }
        statusItem.menu?.addItem(NSMenuItem.separator())
        addConfigurationMenuItem()
    }

    @objc func fetchFeed() {
        let defaults = UserDefaults.standard
        guard let apiKey = defaults.string(forKey: "apiKey") else { return }
        guard !apiKey.isEmpty else {
            statusItem.button?.title = "No API key"
            return
        }
        DispatchQueue.global(qos: .utility).async {
            [unowned self] in
            let latitude = defaults.double(forKey: "latitude")
            let longitude = defaults.double(forKey: "longitude")
            var dataSource = "https://api.openweathermap.org/data/2.5/onecall?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)"
            if defaults.integer(forKey: "units") == 0 {
                dataSource += "&units=metric"
            } else {
                dataSource += "&units=imperial"
            }
            guard let url = URL(string: dataSource) else { return }
            guard let data = try? String(contentsOf: url) else {
                DispatchQueue.main.async {
                    [unowned self] in self.statusItem.button?.title = "Bad API call"
                    print ("Bad API Call")
                }
                return
            }
            let newFeed = JSON(parseJSON: data)
            DispatchQueue.main.async {
                self.feed = newFeed
                self.updateDisplay()
                self.refreshSubmenuItems()
            }
        }
    }
    
    func updateDisplay() {
        guard let feed = feed else { return }
        var text = "Error"
        switch displayMode {
            case 0:
                // weather description
                if let summary = feed["current"]["weather"][0]["description"].string {
                    text = "Summary: \(summary)"
                }
            case 1:
                // Show current temperature
                if let temperature = feed["current"]["temp"].int {
                    text = "Temp: \(temperature)°"
                }
            case 2:
                // Show wind speed and direction as well as gusts
                text = "Winds: "
                if let windDir = feed["current"] ["wind_deg"].int {
                    switch windDir {
                        case 0..<12:
                            text += "N"
                        case 12..<34:
                            text += "NNE"
                        case 34..<56:
                            text += "NE"
                        case 56..<79:
                            text += "ENE"
                        case 79..<101:
                            text += "E"
                        case 101..<124:
                            text += "ESE"
                        case 124..<146:
                            text += "SE"
                        case 146..<169:
                            text += "SSE"
                        case 169..<191:
                            text += "S"
                        case 191..<214:
                            text += "SSW"
                        case 214..<236:
                            text += "SW"
                        case 236..<259:
                            text += "WSW"
                        case 259..<281:
                            text += "W"
                        case 281..<304:
                            text += "WNW"
                        case 304..<326:
                            text += "NW"
                        case 326..<349:
                            text += "NNW"
                        case 349..<361:
                            text += "N"
                        default:
                            text += ""
                    }
                    if let wind = feed["current"] ["wind_speed"].double {
                        text += " @ \(wind)"
                    }
                }
            case 3:
                // Show cloud cover
                if let cloud = feed["current"]["clouds"].int {
                    text = "Cloud: \(cloud)%"
                }
            default:
                // This should not be reached
                break
        }
        statusItem.button?.title = text
    }
    
    @objc func changeDisplayMode() {
        displayMode += 1
        if displayMode > 3 {
            displayMode = 0
        }
        updateDisplay()
    }
    
    func configureUpdateDisplayTimer() {
        guard let statusBarMode = UserDefaults.standard.string(forKey: "statusBarOption") else { return }
        if statusBarMode == "-1" {
            displayMode = 0
            updateDisplayTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(changeDisplayMode), userInfo: nil, repeats: true)
        } else {
            updateDisplayTimer?.invalidate()
        }
    }
}

