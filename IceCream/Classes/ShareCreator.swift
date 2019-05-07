//
//  ShareCreator.swift
//  IceCream
//
//  Created by Roderic Campbell on 5/2/19.
//

import CloudKit

protocol ShareCreatorDelegate: class {
    func shareCreatorDidFail(with error: Error)
    func shareCreatorDidFinish()
}

public class ShareCreator: NSObject {
    let viewController: UIViewController
    let itemName: String
    weak var delegate: ShareCreatorDelegate?

    public init(with viewController: UIViewController, name: String) {
        self.viewController = viewController
        self.itemName = name
        super.init()
    }

    public func share(_ sharingItem: CKRecordConvertible, from view: UIView) {

        let fetch = CKFetchRecordsOperation(recordIDs: [sharingItem.recordID])

        fetch.perRecordCompletionBlock = { (record, recordID, error) in
            // Handle the ckError
            if let ckError = error as? CKError {
                switch ckError.code {
                case .unknownItem:
                    print("Unknown item. The item may not yet exist on the server")
                default:
                    print("default error")
                }
            }
            // Handle any other errors
            else if let error = error {
                print("Error \(error)")
                self.delegate?.shareCreatorDidFail(with: error)
            }
            // handle success case
            else if let record = record, let recordID = recordID {
                print("recordID \(recordID), \(record)")
                DispatchQueue.main.async {
                    self.shareRealRecord(record: record, from: view)
                }
            }
        }

        print("fetching the record")
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        privateDatabase.add(fetch)
    }

    // presents the share view controller
    private func shareRealRecord(record: CKRecord, from view: UIView) {

        let cloudSharingController = UICloudSharingController { [weak self] (controller, completion) in
            self?.shareClosure(rootRecord: record, completion: completion)
        }
        cloudSharingController.popoverPresentationController?.sourceView = view
        cloudSharingController.delegate = self
        viewController.present(cloudSharingController, animated: true)
    }

    func shareClosure(rootRecord: CKRecord, completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {

        let shareRecord = CKShare(rootRecord: rootRecord)
        let recordsToSave = [shareRecord, rootRecord]
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: [])
        operation.perRecordCompletionBlock = { (record, error) in
            if let ckError = error as? CKError {
                self.delegate?.shareCreatorDidFail(with: ckError)
            }
                // Handle other errors
            else if let error = error {
                print("Error sharing \(error)")
                self.delegate?.shareCreatorDidFail(with: error)
            } else {
                print("seemingly successful share")
            }
        }

        operation.modifyRecordsCompletionBlock = { (savedRecords, deletedRecordIDs, error) in
            if let error = error {
                completion(nil, nil, error)
                self.delegate?.shareCreatorDidFail(with: error)
            } else {
                completion(shareRecord, container, nil)
            }
        }
        operation.isAtomic = true
        operation.savePolicy = .ifServerRecordUnchanged
        privateDatabase.add(operation)
    }
}

extension ShareCreator: UICloudSharingControllerDelegate {
    public func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("share failed to save with error \(error)")
        self.delegate?.shareCreatorDidFail(with: error)
    }

    public func itemTitle(for csc: UICloudSharingController) -> String? {
        return itemName
    }
}
