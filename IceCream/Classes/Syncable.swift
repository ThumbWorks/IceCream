//
//  Syncable.swift
//  IceCream
//
//  Created by 蔡越 on 24/05/2018.
//

import Foundation
import CloudKit
import RealmSwift


/// Since `sync` is an informal version of `synchronize`, so we choose the `syncable` word for
/// the ability of synchronization.
public protocol Syncable: class {

    /// CKRecordZone related
    var recordType: String { get }
    var zoneID: CKRecordZone.ID { get }
    
    /// Local storage
    var zoneChangesToken: CKServerChangeToken? { get set }
    var isCustomZoneCreated: Bool { get set }
    
    /// Custom Realm reference
    var realm: Realm { get set }
    
    /// Realm Database related

    /// TODO temporarily adding the dbName for debug purposes
    func registerLocalDatabase(dbName: String) -> NotificationToken
    func cleanUp()

    /// Remote database has indicated that there is a new record which has been added
    func add(record: CKRecord, ignoreTokens: [NotificationToken])

    /// Remote database has indicated that there is an existing record which has been deleted
    func delete(recordID: CKRecord.ID)
    
    /// CloudKit related
    func pushLocalObjectsToCloudKit()
    
    /// Callback
    var pipeToEngine: ((_ recordsToStore: [CKRecord], _ recordIDsToDelete: [CKRecord.ID]) -> ())? { get set }
    
}
