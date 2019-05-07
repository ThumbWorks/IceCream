//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

import CloudKit
import RealmSwift

/// SyncEngine talks to CloudKit directly.
/// Logically,
/// 1. it takes care of the operations of **CKDatabase**
/// 2. it handles all of the CloudKit config stuffs, such as subscriptions
/// 3. it hands over CKRecordZone stuffs to SyncObject so that it can have an effect on local Realm Database

public final class SyncEngine {
    
    private let privateDatabaseManager: DatabaseManager
    private let publicDatabaseManager: DatabaseManager
    private let sharedDatabaseManager: DatabaseManager

//    init() {}
    public init(objects: [Syncable], container: CKContainer = .default()) {
        privateDatabaseManager = PrivateDatabaseManager(objects: objects, container: container)
        publicDatabaseManager = PublicDatabaseManager(objects: objects, container: container)
        sharedDatabaseManager = SharedDatabaseManager(objects: objects, container: container)
        setup()
    }
    
    public func setup() {

        privateDatabaseManager.prepare()
        [privateDatabaseManager, sharedDatabaseManager, publicDatabaseManager].forEach {
            let manager: DatabaseManager = $0
//            manager.prepare() I took this out so the public wouldn't be synced every time i added anything to the realm. We only want it to pipe to private. At this point, or somewhere near here we would need to explicitly state which database is the default database to add objects to. Should be either public or private and not shared since shared is handled by CloudKit
            manager.container.accountStatus { (status, error) in
                switch status {
                case .available:
                    manager.registerLocalDatabase()
                    manager.createCustomZonesIfAllowed()
                    manager.fetchChangesInDatabase({
                        print("changes have been fetched in this manager")
                    })
                    manager.resumeLongLivedOperationIfPossible()
                    manager.startObservingRemoteChanges()
                    manager.startObservingTermination()
                    #if os(iOS) || os(tvOS) || os(macOS)
                    manager.createDatabaseSubscriptionIfHaveNot()
                    #endif
                case .noAccount, .restricted:
                    guard manager is PublicDatabaseManager else { break }
                    manager.fetchChangesInDatabase(nil)
                    manager.resumeLongLivedOperationIfPossible()
                    manager.startObservingRemoteChanges()
                    manager.startObservingTermination()
                    #if os(iOS) || os(tvOS) || os(macOS)
                    manager.createDatabaseSubscriptionIfHaveNot()
                    #endif
                case .couldNotDetermine:
                    break
                }
            }
        }

        // set up the ignored tokens for each database type. Each ignores the others.
        var privateDatabaseTokensToIgnore = [NotificationToken]()
        privateDatabaseTokensToIgnore.append(contentsOf: publicDatabaseManager.ignoreTokens)
        privateDatabaseTokensToIgnore.append(contentsOf: sharedDatabaseManager.ignoreTokens)
        privateDatabaseManager.ignoreTokens = privateDatabaseTokensToIgnore

        var sharedDatabaseTokensToIgnore = [NotificationToken]()
        sharedDatabaseTokensToIgnore.append(contentsOf: privateDatabaseManager.ignoreTokens)
        sharedDatabaseTokensToIgnore.append(contentsOf: publicDatabaseManager.ignoreTokens)
        sharedDatabaseManager.ignoreTokens = sharedDatabaseTokensToIgnore

        var publicDatabaseTokensToIgnore = [NotificationToken]()
        publicDatabaseTokensToIgnore.append(contentsOf: privateDatabaseManager.ignoreTokens)
        publicDatabaseTokensToIgnore.append(contentsOf: sharedDatabaseManager.ignoreTokens)
        publicDatabaseManager.ignoreTokens = publicDatabaseTokensToIgnore
    }
    
}

// MARK: Public Method
extension SyncEngine {
    /// Fetch data on the CloudKit and merge with local
    public func pull() {
        privateDatabaseManager.fetchChangesInDatabase(nil)
        publicDatabaseManager.fetchChangesInDatabase(nil)
        sharedDatabaseManager.fetchChangesInDatabase(nil)
    }
    
    /// Push all existing local data to CloudKit
    /// You should NOT to call this method too frequently
    public func pushAll() {
        privateDatabaseManager.syncObjects.forEach { $0.pushLocalObjectsToCloudKit() }
        publicDatabaseManager.syncObjects.forEach { $0.pushLocalObjectsToCloudKit() }
        sharedDatabaseManager.syncObjects.forEach { $0.pushLocalObjectsToCloudKit() }
    }
}

public enum Notifications: String, NotificationName {
    case cloudKitDataDidChangeRemotely
}

public enum IceCreamKey: String {
    /// Tokens
    case databaseChangesTokenKey
    case zoneChangesTokenKey
    
    /// Flags
    case subscriptionIsLocallyCachedKey
    case hasCustomZoneCreatedKey
    
    var value: String {
        return "icecream.keys." + rawValue
    }
}

/// Dangerous part:
/// In most cases, you should not change the string value cause it is related to user settings.
/// e.g.: the cloudKitSubscriptionID, if you don't want to use "private_changes" and use another string. You should remove the old subsription first.
/// Or your user will not save the same subscription again. So you got trouble.
/// The right way is remove old subscription first and then save new subscription.
public enum IceCreamSubscription: String, CaseIterable {
    case cloudKitSharedDatabaseSubscriptionID = "shared_changes"
    case cloudKitPrivateDatabaseSubscriptionID = "private_changes"
    case cloudKitPublicDatabaseSubscriptionID = "cloudKitPublicDatabaseSubcriptionID"
    
    var id: String {
        return rawValue
    }
    
    public static var allIDs: [String] {
        return IceCreamSubscription.allCases.map { $0.rawValue }
    }
}
