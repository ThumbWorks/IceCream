//
//  CatsViewController.swift
//  IceCream_Example
//
//  Created by 蔡越 on 22/05/2018.
//  Copyright © 2018 蔡越. All rights reserved.
//

import UIKit
import RealmSwift
import IceCream
import RxRealm
import RxSwift

class CatsViewController: UIViewController {
    
    var cats: [Cat] = []
    let bag = DisposeBag()
    
    let realm = try! Realm()

    var shareCreator: ShareCreator?

    lazy var addBarItem: UIBarButtonItem = {
        let b = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(add))
        return b
    }()
    
    lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.delegate = self
        tv.dataSource = self
        return tv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        navigationItem.rightBarButtonItem = addBarItem
        title = "Cats"
        
        bind()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.frame
    }
    
    func bind() {
        let realm = try! Realm()
        
        /// Results instances are live, auto-updating views into the underlying data, which means results never have to be re-fetched.
        /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
        let cats = realm.objects(Cat.self)
        
        Observable.array(from: cats).subscribe(onNext: { (cats) in
            /// When cats data changes in Realm, the following code will be executed
            /// It works like magic.
            self.cats = cats.filter{ !$0.isDeleted }
            self.tableView.reloadData()
        }).disposed(by: bag)
    }
    
    @objc func add() {
        let cat = Cat()
        cat.name = "Cat Number " + "\(cats.count)"
        cat.age = cats.count + 1
        
        let data = UIImageJPEGRepresentation(UIImage(named: cat.age % 2 == 1 ? "heart_cat" : "dull_cat")!, 1.0) as Data!
        cat.avatar = CreamAsset.create(object: cat, propName: Cat.AVATAR_KEY, data: data!)

        // TODO this is where we add the cat, we may need to write without notifying the shared database
        try! realm.write {
            realm.add(cat)
        }
    }
    
}

extension CatsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (_, ip) in
            let alert = UIAlertController(title: NSLocalizedString("caution", comment: "caution"), message: NSLocalizedString("sure_to_delete", comment: "sure_to_delete"), preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: NSLocalizedString("delete", comment: "delete"), style: .destructive, handler: { (action) in
                guard ip.row < self.cats.count else { return }
                let cat = self.cats[ip.row]
                try! self.realm.write {
                    cat.isDeleted = true
                }
            })
            let defaultAction = UIAlertAction(title: NSLocalizedString("cancel", comment: "cancel"), style: .default, handler: nil)
            alert.addAction(defaultAction)
            alert.addAction(deleteAction)
            self.present(alert, animated: true, completion: nil)
        }
        
        let incrementAgeAction = UITableViewRowAction(style: .normal, title: "Plus") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                cat.age += 1
            }
        }
        let renameImageAction = UITableViewRowAction(style: .normal, title: "Change Name") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]

            let alert = UIAlertController(title: "New Name", message: nil, preferredStyle: .alert)
            alert.addTextField(configurationHandler: nil)

            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (alertObject) in
                guard let text = alert.textFields?.first?.text else {
                    print("no text field or text")
                    return
                }
                try! `self`.realm.write {
                    cat.name = text
                }
            }))
            `self`.present(alert, animated: true)
        }
        renameImageAction.backgroundColor = .orange

        let changeImageAction = UITableViewRowAction(style: .normal, title: "Change Img") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                if let imageData = UIImageJPEGRepresentation(UIImage(named: cat.age % 2 == 0 ? "heart_cat" : "dull_cat")!, 1.0) {
                    cat.avatar = CreamAsset.create(object: cat, propName: Cat.AVATAR_KEY, data: imageData)
                }
            }
        }
        changeImageAction.backgroundColor = .blue

        let emptyImageAction = UITableViewRowAction(style: .normal, title: "Nil Img") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                cat.avatar = nil
            }
        }
        emptyImageAction.backgroundColor = .purple

        let shareAction = UITableViewRowAction(style: .normal, title: "Share") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            self.shareCreator = ShareCreator(with: self, name: cat.name )
            self.shareCreator?.share(cat, from: self.view)
        }
        shareAction.backgroundColor = .green
        return [deleteAction,
                // TODO removing these just for testing share functionality
//                incrementAgeAction,
//                changeImageAction,
//                emptyImageAction,
                renameImageAction,
                shareAction]
    }
}

extension CatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = cats[indexPath.row].name + " Age: \(cats[indexPath.row].age)"
        if let data = cats[indexPath.row].avatar?.storedData() {
            cell?.imageView?.image = UIImage(data: data)
        } else {
            cell?.imageView?.image = UIImage(named: "cat_placeholder")
        }
        return cell ?? UITableViewCell()
    }
}
