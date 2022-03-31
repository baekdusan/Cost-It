import UIKit

protocol shareRevenueFinList {
    func sendRFinList(_ viewController: revenueVC, _ rFinList: [finData])
}

class revenueVC: UIViewController, sendRevenueFinData {
    // 수입 데이터 추가 프로토콜
    func sendRevenueData(_ controller: addFinVC, _ originData: finData, _ revisedData: finData) {
        // 일반적인 추가
        if originData == revisedData {
            rfinList.append(revisedData)
        // 수정일 때 -> 원래 데이터 삭제 후, 새로운 데이터 추가
        } else {
            let removedData = originData
            rfinList.remove(at: rfinList.firstIndex(where: {$0 == removedData})!)
            rfinList.append(revisedData)
        }
        updateLayout()
    }
    
    @IBOutlet weak var navigation: UINavigationBar!
    @IBOutlet weak var collectionView: UICollectionView! // 콜렉션 뷰
    @IBOutlet weak var dismissBtn: UIButton!
    @IBOutlet weak var addBtnLayOut: UIButton! // 소득 추가 버튼
    
    var rfinList: [finData] = [] {
        didSet {
            if let delegate = rdelegate {
                delegate.sendRFinList(self, rfinList)
            }
        }
    }
    var filtered: [finData] = [] // 필터링된 소득 가계부 데이터
    var start: Date!
    var end: Date!
    var rdelegate: shareRevenueFinList!
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addRevenueFinData" {
            // 소득을 추가할 때는 기간 내에 시작과 끝점, 그리고 추가 뷰가 소득 뷰에서부터 왔다는 것을 알려줘야함
            let vc = segue.destination as! addFinVC
            vc.fromWhere = .revenue
            vc.mode = .new
            vc.start = start
            vc.end = end
            vc.rDelegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 네비게이션 바 투명처리
        navigation.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigation.shadowImage = UIImage()
        
        // 네비게이션 바 타이틀 레이아웃 설정
        let title = UILabel()
        title.text = start.toString(false) + " ~ " + end.toString(false)
        title.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        title.textColor = UIColor(named: "customLabel")
        navigation.topItem?.titleView = title
        
        // 버튼 동그랗게 + 투명도 조절
        addBtnLayOut.btnLayout(false)
        dismissBtn.btnLayout(false)
        
        // 지출 뷰에서 받아온 기간으로 가계부 데이터 필터링
        filteredbyMonth(start, end)
    }
    @IBAction func dismissBtn(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
            
    }
    
    func updateLayout() {
        filteredbyMonth(start, end) // 이번 달에 맞춰서 filteredList 할당
        
        // 콜렉션뷰 갱신, 위젯 갱신
        collectionView.reloadData()
    }
    
    // 콜렉션 뷰에 넣을 데이터대로 셋팅 (섹션, 로우 나누고 정렬)
    func filteredbyMonth(_ startDate: Date, _ endDate: Date) {
        filtered.removeAll()
        filtered = rfinList.filter { $0.when >= startDate && $0.when <= endDate}
        filtered.sort { $0.when > $1.when }
    }
    
    // 총 소득액
    func totalMoney() -> Int {
        var total : Int = 0
        for i in filtered {
            total += i.how
        }
        return total
    }
    
    @objc func dismissView() {
        dismiss(animated: true, completion: nil)
    }
    
    // 삭제 버튼 (touch up inside)
    @objc func cancelButtonAction(sender : UIButton) {
        let row = sender.tag
        let alert = UIAlertController(title: "삭제", message: "해당 수입 내역을 삭제해요.", preferredStyle: .alert)
        
        let cancel = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        let ok = UIAlertAction(title: "확인", style: .default, handler: { [self]_ in
            deleteRFindata(row)
        })
        
        alert.addAction(cancel)
        alert.addAction(ok)
        
        present(alert, animated: true, completion: nil)
    }
    
    func deleteRFindata(_ row: Int) {
        collectionView.performBatchUpdates({
            
            collectionView.deleteItems(at: [IndexPath.init(row: row, section: 0)])
            let removedStr = filtered.remove(at: row)
            rfinList.remove(at: rfinList.firstIndex(where: {$0 == removedStr})!)
            
        }, completion: { [self] _ in collectionView.reloadData()})
    }
    
    // 수정 버튼(꾹 누르는 제스처)
    @objc func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {

        if longPressGestureRecognizer.state == UIGestureRecognizer.State.began {
            let touchPoint = longPressGestureRecognizer.location(in: collectionView)
            if let index = collectionView.indexPathForItem(at: touchPoint) {
                let row = index[1]
                guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "addFinData") as? addFinVC else { return }
                vc.fromWhere = .revenue
                vc.mode = .edit
                vc.originData = filtered[row]
                vc.rDelegate = self
                vc.modalPresentationStyle = .overFullScreen
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
}

extension revenueVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    // 섹션 개수 -> 최대 31개(한달 최대 일수)
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    // 섹션당 로우 개수
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filtered.count
    }
    
    // 컬렉션 뷰 레이아웃
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let deepTouchGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "rCell", for: indexPath) as? rCell else {
            return UICollectionViewCell()
        }
        cell.updateUI(filtered, indexPath.row)
        cell.makeShadow()
        cell.dismiss.tag = indexPath.row
        cell.dismiss.addTarget(self, action: #selector(cancelButtonAction(sender:)), for: .touchUpInside)
        cell.border.addGestureRecognizer(deepTouchGesture)
        return cell
    }
    
    // 컬렉션 헤더 뷰 레이아웃
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "rHeader", for: indexPath) as? rheader else { return UICollectionReusableView() }
            headerView.updateHeader(filtered, indexPath.section)
            headerView.makeShadow()
            return headerView
        default: assert(false, "nil")
        }
        return UICollectionReusableView()
    }
}

extension revenueVC: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = view.bounds.width * 0.9
        let height = CGFloat(78)
        
        return CGSize(width: width, height: height)
    }
}

class rCell: UICollectionViewCell {
    
    @IBOutlet weak var when: UILabel!
    @IBOutlet weak var towhat: UILabel!
    @IBOutlet weak var how: UILabel!
    @IBOutlet weak var dismiss: UIButton!
    @IBOutlet weak var border: UIView!
    
    func updateUI(_ model: [finData], _ row: Int) {
    
    when.text = model[row].when.toString(false)
    towhat.text = model[row].towhat
    how.text = "+ " + model[row].how.toDecimal()
}
    
    func makeShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.masksToBounds = false
    }
}

// 컬렉션 헤더 뷰 클래스
class rheader: UICollectionReusableView {

    @IBOutlet weak var headerDate: UILabel!
    
    func updateHeader(_ arr: [finData], _ index: Int) {
            
        if arr.isEmpty {
            headerDate.text = "₩ 0"
        } else {
            var total = 0
            for i in arr {
                total += i.how
            }
            headerDate.text = "₩ " + total.toDecimal()
        }
    }
    
    func makeShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.masksToBounds = true
    }
}

