//
//  AppDelegate.swift
//  IceCream
//
//  Created by 蔡越 on 10/17/2017.
//  Copyright (c) 2017 Nanjing University. All rights reserved.
//

import UIKit
import IceCream
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var syncEngine: SyncEngine?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        syncEngine = SyncEngine(objects: [
            SyncObject<Person>(),
            SyncObject<Dog>(),
            SyncObject<Cat>()
            ])

        /// If you wanna test public Database, comment the above syncEngine code and uncomment the following one
        /// Besides, uncomment Line 26 to 28 in Person.swift file
//        syncEngine = SyncEngine(objects: [SyncObject<Person>()], databaseScope: .public)
      
        application.registerForRemoteNotifications()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = TabBarViewController()
        window?.makeKeyAndVisible()
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        let dict = userInfo as! [String: NSObject]
        let notification = CKNotification(fromRemoteNotificationDictionary: dict)
        
        if let subscriptionID = notification.subscriptionID, IceCreamSubscription.allIDs.contains(subscriptionID) {
             NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
        }
        completionHandler(.newData)
        
    }

    // ok so now that this method is here I need to add the UI components of the share inside of the object. maybe an API on the sync engine or something called `.share()`. CKConvertible maybe? I'll need to think about it more
    internal func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        print("Hey we accepted the share")
        let container = CKContainer.default()

        container.accept(cloudKitShareMetadata) { (share, error) in
            if let error = error {
                print("accepting the share \(error)")
            }
            if let share = share {
                share.participants.forEach({ participant in
                    print("participant \(participant)")
                })
                print("Cool we have a share. I guess we show it?")
            }
        }

    }
}

