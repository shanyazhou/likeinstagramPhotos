//
//  Test4ViewController.swift
//  MU
//
//  Created by shanyazhou on 2016/12/30.
//  Copyright © 2016年 li. All rights reserved.
//

import UIKit
import Photos
import AssetsLibrary


private let reuseIdentifier = "MUAddPVCollectionViewCell"

class MUAddPVViewController: UIViewController, UIGestureRecognizerDelegate, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Property
    fileprivate var thumbnailSize: CGSize!
    var middleHeightConstantMax: CGFloat = 0.0
    let middleHeightConstantMin: CGFloat = 70.0
    var historyY: CGFloat = 0.0
    var selectedType: Int = 1
    var fetchResult: PHFetchResult<PHAsset>!
    fileprivate let imageManager = PHCachingImageManager()
    var bigImageView: UIImageView?
    var bigVideoView: UIView?
    var bigVideoImage: UIImage? //视频省略图
    var bigVideoPlayer: AVPlayer?
    var bigImageViewFinishScale: CGFloat = 1
    var bigViewIsSelected: Bool = true
    var bigVideoOriginalSizeWidth: Int = 0
    var bigVideoOriginalSizeHeight: Int = 0
    var bigOriginalImage: UIImage?
    var bigVideoIsOriginalSize: Bool = false
    var nextBtn: UIButton?
    fileprivate var playerLayer: AVPlayerLayer!
    //视频预览时的宽高
    var videoPlayWidth: CGFloat = 0
    var videoPlayHeight: CGFloat = 0
    var videoScrollEndPointX: CGFloat = 0
    var videoScrollEndPointY: CGFloat = 0
    //点击视频的路径URL
    var videoPathURL: URL?
    var videoTimeLength: Int = 0

    @IBOutlet weak var blueViewHeight: NSLayoutConstraint!
    @IBOutlet weak var collectionView1: UICollectionView!
    @IBOutlet weak var redView: UIView!//下面的collectionView放在它上面
    @IBOutlet weak var blueView: UIView!
    @IBOutlet weak var topScrollView: UIScrollView!
    @IBOutlet weak var middleHeight: NSLayoutConstraint!
    @IBOutlet weak var middleView: UIView!//中间的遮盖View
    @IBOutlet weak var ToolView: UIView!
    @IBOutlet weak var originalSizeBtn: UIButton!
    
    //第一次进入时，需要判断是否可以使用相册
    static func show(vc:UIViewController) {
        PHPhotoLibrary.requestAuthorization { (status) in
            if status == .authorized {
                let photoVideoViewController = UIStoryboard(name: "MUAddPVSend", bundle: nil).instantiateViewController(withIdentifier: "MUAddPVViewController") as! MUAddPVViewController
                let navigationController = UINavigationController(rootViewController: photoVideoViewController)
                vc.present(navigationController, animated: true, completion: nil)
            }else {
                let alertController = UIAlertController(title: nil, message: "请在“设置-隐私-照片”中允许访问照片", preferredStyle: UIAlertControllerStyle.alert)
                let cancelAction = UIAlertAction(title: "取消", style: UIAlertActionStyle.cancel, handler: nil)
                let okAction = UIAlertAction(title: "好的", style: UIAlertActionStyle.default, handler: nil)
                alertController.addAction(cancelAction)
                alertController.addAction(okAction)
                vc.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    
    deinit {
        printLog("MUAddPVViewController deinit")
    }
    
    // MARK: - Life Cycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isStatusBarHidden = true
        middleHeightConstantMax = kScreenWidth + (navigationController?.navigationBar.frame.size.height)! - 10
        self.middleHeight.constant = middleHeightConstantMax
        originalSizeBtn.isHidden = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bigVideoPlayer?.pause()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMiddleView()
        setupTopScrollView()
        setupNav()
        setupToolView()
        //默认选中第一个cell
        let defaultSelectCell = IndexPath(row: 0, section: 0)
        collectionView(collectionView, didSelectItemAt: defaultSelectCell)
        //需要把中间那个View一直提到最前面
        view.bringSubview(toFront: middleView)
    }

    // MARK: - Set up
    
    private func setupMiddleView()
    {
        let middleView = self.middleView
        middleView?.backgroundColor = UIColor.clear
        //拖拽手势
        let pan = UIPanGestureRecognizer(target: self, action:#selector(panGesture(pan:)))
        middleView?.addGestureRecognizer(pan)
        pan.delegate = self
        //轻扫手势
        let swipeGestureUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(swipeGesture:)))
        let swipeGestureDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(swipeGesture:)))
        swipeGestureUp.direction = UISwipeGestureRecognizerDirection.up
        swipeGestureDown.direction = UISwipeGestureRecognizerDirection.down
        middleView?.addGestureRecognizer(swipeGestureUp)
        middleView?.addGestureRecognizer(swipeGestureDown)
        swipeGestureUp.delegate = self
        swipeGestureDown.delegate = self
    }
    
    
    private func setupTopScrollView()
    {
        let topScrollView = self.topScrollView
        topScrollView?.showsHorizontalScrollIndicator = false
        topScrollView?.showsVerticalScrollIndicator = false
        topScrollView?.delegate = self;
        topScrollView?.isScrollEnabled = true
        topScrollView?.frame = CGRect(x: 0, y: 0, width: kScreenWidth, height: kScreenWidth)
        //必须加上，不然上面会有一段空白
        self.automaticallyAdjustsScrollViewInsets = false
        
        let bigImageView = UIImageView()
        self.bigImageView = bigImageView
        topScrollView?.addSubview(self.bigImageView!)
        self.bigImageView?.isHidden = true
        
        let bigVideoView = UIView()
        self.bigVideoView = bigVideoView
        topScrollView?.addSubview(self.bigVideoView!)
        self.bigVideoView?.isHidden = true
        
        originalSizeBtn.addTarget(self, action: #selector(self.changeBigViewSize), for: .touchUpInside)
    }
    
    private func setupNav()
    {
        navigationItem.titleView = naviTitleLabel(title: "添加照片/视频")
        navigationItem.leftBarButtonItem = UIBarButtonItem(imageName: nil, title: "取消", target: self, action: #selector(self.addPhotoVideoCancel))
        
        let btn:UIButton = UIButton()
        btn.setTitle("下一步", for: UIControlState.normal)
        btn.addTarget(self, action: #selector(self.rightItemClick), for: UIControlEvents.touchUpInside)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        btn.setTitleColor(BLUE, for: .normal)
        btn.setTitleColor(GRAY_99, for: .highlighted)
        btn.setTitleColor(RGB(r: 0x66, g: 0x66, b: 0x66, alpha: 0.3), for: .disabled)
        btn.sizeToFit()
        nextBtn = btn
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: nextBtn!)
    }
    
    
    private func setupToolView()
    {
        let btn_width = kScreenWidth / 2
        let btn_height = ToolView.height
        
        let photoVideoBtn = setupToolBtn(title: "图库", titleColor:UIColor.black)
        photoVideoBtn.frame = CGRect(x: 0, y: 0, width: btn_width, height: btn_height)
        
        let liveBtn = setupToolBtn(title: "直播", titleColor:UIColor.gray)
        liveBtn.frame = CGRect(x: btn_width, y: 0, width: btn_width, height: btn_height)
        liveBtn.addTarget(self, action: #selector(MUAddPVViewController.liveBtnClick), for: .touchUpInside)
    }
    
    
    // MARK: - Func
    
    private func setupToolBtn(title: String, titleColor: UIColor) -> UIButton
    {
        let toolBtn = UIButton()
        toolBtn.setTitle(title, for: UIControlState.normal)
        toolBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFontWeightRegular)
        toolBtn.setTitleColor(titleColor, for: .normal)
        ToolView.addSubview(toolBtn)
        return toolBtn
    }
    
    
    //判断视频是否需要旋转90度
    private func degressFromVideoFileWithURL(url: URL) -> Int
    {
        var degress = 0
        let asset: AVAsset = AVAsset.init(url: url)
        let tracks = asset.tracks(withMediaType: AVMediaTypeVideo)
        if(tracks.count > 0) {
            let videoTrack = tracks.first
            let t = videoTrack?.preferredTransform
            if(t?.a == 0 && t?.b == 1 && t?.c == -1 && t?.d == 0)
            {
                degress = 90;
            } else if (t?.a == 0 && t?.b == -1.0 && t?.c == 1.0 && t?.d == 0) {
                // PortraitUpsideDown
                degress = 270;
                
            } else if (t?.a == 1 && t?.b == 0 && t?.c == 0 && t?.d == 1.0) {
                // LandscapeRight
                degress = 0
            } else if (t?.a == -1.0 && t?.b == 0 && t?.c == 0 && t?.d == -1.0) {
                // LandscapeLeft
                degress = 180;
            }
        }
        return degress
    }
    
    
    //对视频剪切进行约束，确保在0-1之间
    private func contractRange(N: CGFloat) -> CGFloat
    {
        if N > 1 {
            return  1
        } else if N < 0 {
            return 0
        } else {
            return N
        }
    }
    
    private func getNewCropImage(oldImage: UIImage) -> UIImage
    {
        if ((bigImageView?.size.width)! >= kScreenWidth) && ((bigImageView?.size.height)! >= kScreenWidth)
        {
            return screenshotImage(view: blueView)
        } else {
            //老图形与新图形的比例
            let oldNewScale = oldImage.size.width / (bigImageView?.size.width)!
            
            let X: CGFloat = videoScrollEndPointX * oldNewScale
            let Y: CGFloat = videoScrollEndPointY * oldNewScale
            var W: CGFloat = 0
            var H: CGFloat = 0
            
            if (bigImageView?.origin.x)! > CGFloat(0)
            {
                let needWHScale = (bigImageView?.size.width)! / kScreenWidth
                
                W = oldImage.size.width
                H = W / needWHScale
            } else if (bigImageView?.origin.y)! > CGFloat(0)
            {
                let needWHScale = (bigImageView?.size.height)! / kScreenWidth
                
                H = oldImage.size.height
                W = H / needWHScale
            }else {
                return (bigImageView?.image)!
            }

            return oldImage.yy_imageByCrop(to: CGRect(x: X, y: Y, width: W, height: H))!
        }
    }
    
    //截屏保存选中的图片
    private func screenshotImage(view: UIView) -> UIImage
    {
        originalSizeBtn.isHidden = true//需要把左下角的放大放小按钮隐藏
        
        let screenshotSize = CGSize(width: kScreenWidth, height: blueView.frame.size.height)
        UIGraphicsBeginImageContextWithOptions(screenshotSize, false, UIScreen.main.scale)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        //结束上下文
        UIGraphicsEndImageContext()
        return newImage!
    }

    //缩放后的视频\图需要居中显示
    private func setViewCenterInScrollView(view: UIView, scrollView: UIScrollView, isSelected: Bool)
    {
        scrollView.setContentOffset(CGPoint(x: 0, y:0), animated: false)
        let offsetX: CGFloat = (scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0
        let offsetY: CGFloat = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0
        view.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
        
        //视频\图大于所见框
        if (scrollView.bounds.size.width < scrollView.contentSize.width) || (scrollView.bounds.size.height < scrollView.contentSize.height)
        {
            let offsetX: CGFloat = (scrollView.bounds.size.width < scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0
            let offsetY: CGFloat = (scrollView.bounds.size.height < scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0
            let contentOffset = scrollView.contentOffset
            scrollView.setContentOffset(CGPoint(x: contentOffset.x - offsetX, y:contentOffset.y - offsetY), animated: false)
        }else {
            let offsetX: CGFloat = (scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0
            let offsetY: CGFloat = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0
            view.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
        }
    }
    
    //设置图片的尺寸
    private func setupBigImageView(image: UIImage, isSelected: Bool)
    {
        let widthScale = self.topScrollView.frame.size.width/(self.bigImageView?.image!.size.width)!/1.0
        let heightScale = self.topScrollView.frame.size.height/(self.bigImageView?.image!.size.height)!/1.0
        
        var scale:CGFloat = 0.0
        if isSelected == true {
            scale = min(widthScale, heightScale)//小图(原图)
            var w = (self.bigImageView?.image!.size.width)! * scale
            var h = (self.bigImageView?.image!.size.height)! * scale
            
            let bigImageMinWidth = kScreenWidth - 2 * 36.0
            let bigImageMinHeight = kScreenWidth/2
            
            if w < bigImageMinWidth
            {
                let widthExpandScale = bigImageMinWidth / w
                w = bigImageMinWidth
                h = h * widthExpandScale
                //宽度小于最小宽度，宽度变大，高度就是kScreenWidth
            }
            if h < bigImageMinHeight
            {
                let heightExpandScale = bigImageMinHeight / h
                h = bigImageMinHeight
                w = w * heightExpandScale
            }
            self.bigImageView?.frame = CGRect(x: 0, y: 0, width: w, height: h)
        }else {
            scale = max(widthScale, heightScale)//大图(需要剪切的图)
            let w = (self.bigImageView?.image!.size.width)! * scale
            let h = (self.bigImageView?.image!.size.height)! * scale
            self.bigImageView?.frame = CGRect(x: 0, y: 0, width: w, height: h)
        }
        
        //contentSize必须设置,否则无法滚动，当前设置为图片大小
        //设置这两个内容相等
        self.topScrollView.contentSize = (self.bigImageView?.frame.size)!
        //自适应
        self.bigImageView?.contentMode = UIViewContentMode.scaleAspectFill
    }
    
    //大屏幕video
    private func setupBigVideoView(width: Int , height: Int, isSelected: Bool)
    {
        //添加新的video
        let widthScale = self.topScrollView.frame.size.width/CGFloat(width)/1.0
        let heightScale = self.topScrollView.frame.size.height/CGFloat(height)/1.0
        
        var scale:CGFloat = 0.0
        if isSelected == true {
            scale = min(widthScale, heightScale)//小视频(原视频)
            bigVideoIsOriginalSize = true
            
            var w = CGFloat(width) * scale
            var h = CGFloat(height) * scale
            
            let bigVideoMinWidth = kScreenWidth - 2 * 36.0
            let bigVideoMinHeight = kScreenWidth/2
            
            if w < bigVideoMinWidth
            {
                let widthExpandScale = bigVideoMinWidth / w
                w = bigVideoMinWidth
                h = h * widthExpandScale
                //宽度小于最小宽度，宽度变大，高度就是kScreenWidth
            }
            if h < bigVideoMinHeight
            {
                let heightExpandScale = bigVideoMinHeight / h
                h = bigVideoMinHeight
                w = w * heightExpandScale
            }
            videoPlayWidth = w
            videoPlayHeight = h
            self.bigVideoView?.frame = CGRect(x: 0, y: 0, width: w, height: h)
        }else {
            scale = max(widthScale, heightScale)//大视频(需要剪切的视频)
            bigVideoIsOriginalSize = false
            let w = CGFloat(width) * scale
            let h = CGFloat(height) * scale
            videoPlayWidth = w
            videoPlayHeight = h
            self.bigVideoView?.frame = CGRect(x: 0, y: 0, width: w, height: h)
        }
        
        //contentSize必须设置,否则无法滚动
        //设置这两个内容相等
        self.topScrollView.contentSize = (self.bigVideoView?.frame.size)!
        
        topScrollView.setContentOffset(CGPoint(x: 0, y:0), animated: false)
        //自适应
        self.bigVideoView?.contentMode = UIViewContentMode.scaleAspectFill
    }

    
    //缩放后的图片需要居中显示
    fileprivate func setImageviewCenterInScrollView(scrollView: UIScrollView)
    {
        let offsetX: CGFloat = scrollView.bounds.size.width > scrollView.contentSize.width ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0
        
        let offsetY: CGFloat = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0
        
        self.bigImageView?.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                            
                                            y: scrollView.contentSize.height * 0.5 + offsetY)
        
    }
    
    
    //缩放后的视频\图需要居中显示
    fileprivate func setViewCenterInScrollView(view: UIView, scrollView: UIScrollView)
    {
        scrollView.setContentOffset(CGPoint(x: 0, y:0), animated: false)
        
        //视频\图大于所见框
        if (scrollView.bounds.size.width < scrollView.contentSize.width) || (scrollView.bounds.size.height < scrollView.contentSize.height)
        {
            let offsetX: CGFloat = (scrollView.bounds.size.width < scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0
            let offsetY: CGFloat = (scrollView.bounds.size.height < scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0
            let contentOffset = scrollView.contentOffset
            scrollView.setContentOffset(CGPoint(x: contentOffset.x - offsetX, y:contentOffset.y - offsetY), animated: false)
        }else {
            let offsetX: CGFloat = (scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0
            let offsetY: CGFloat = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0
            view.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
        }
        
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    //MARK: - Action
    
    @objc private func liveBtnClick()
    {
        let startLive = MUStartLiveController()
        self.present(startLive, animated: true, completion: nil)
    }
    
    @objc private func addPhotoVideoCancel()
    {
        dismiss(animated: true, completion: nil)
    }
    
    //轻扫
    @objc private func handleSwipeGesture(swipeGesture:UISwipeGestureRecognizer)
    {
        //划动的方向
        let direction = swipeGesture.direction
        //判断是上下左右
        if direction == UISwipeGestureRecognizerDirection.up
        {
            printLog("up")
            self.middleHeight.constant = middleHeightConstantMin
            UIView.animate(withDuration: 0.3, animations: {
                self.view.layoutIfNeeded()
            })
            DispatchQueue.main.async {
                self.popView.removeFromSuperview()
                self.popWindow.removeFromSuperview()
            }
            
        }else if direction == UISwipeGestureRecognizerDirection.down
        {
            printLog("down")
            self.middleHeight.constant = middleHeightConstantMax
            UIView.animate(withDuration: 0.3, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }
    
    @objc private func panGesture(pan: UIPanGestureRecognizer)
    {
        let translation = pan.translation(in: pan.view)
        var center = pan.view!.center
        center.y = center.y + translation.y
        pan.view?.center = center
        pan.setTranslation(CGPoint(x:0,y:0), in: pan.view)
        if middleHeight.constant >= middleHeightConstantMax
        {
            middleHeight.constant = middleHeightConstantMax
        }else if middleHeight.constant <= middleHeightConstantMin
        {
            middleHeight.constant = middleHeightConstantMin
        }
        
        middleHeight.constant = middleHeight.constant + translation.y
    }
    
    @objc private func changeBigViewSize()
    {
        if selectedType == 1
        {
            setupBigImageView(image: bigOriginalImage!, isSelected: bigViewIsSelected)
            setViewCenterInScrollView(view: bigImageView!, scrollView: topScrollView, isSelected: bigViewIsSelected)
        }else if selectedType == 2
        {
            setupBigVideoView(width: bigVideoOriginalSizeWidth, height: bigVideoOriginalSizeHeight, isSelected: bigViewIsSelected)
            setViewCenterInScrollView(view: bigVideoView!, scrollView: topScrollView, isSelected: bigViewIsSelected)
            
            playerLayer.frame = (self.bigVideoView?.layer.bounds)!//这个有问题
            //            if var plate = playerLayer
            //            {
            //                plate.frame = (self.bigVideoView?.layer.bounds)!
            //                playerLayer.frame = plate.frame
            //            }
            
        }
        bigViewIsSelected = !bigViewIsSelected
    }
    
    @objc private func rightItemClick()
    {
        let sendPhotoAndVideoCV = MUSendPhotoAndVideoTableViewController()
        sendPhotoAndVideoCV.selectedType = selectedType
        if (selectedType == 1)
        {
            sendPhotoAndVideoCV.iconImage = getNewCropImage(oldImage: (bigImageView?.image)!)
            originalSizeBtn.isHidden = false
        }else if(selectedType == 2)
        {
            sendPhotoAndVideoCV.iconImage = bigVideoImage
            //剪切+约束
            //x,y,w,h分别从0-1，是一个比例数
            //x：左上角的点/视频宽度  y:左上角的y点/视频高度  w:屏幕宽度/视频宽度 h:屏幕高度/视频高度
            sendPhotoAndVideoCV.videoPathURL = videoPathURL
            //判断是否90度
            if degressFromVideoFileWithURL(url: videoPathURL!) == 90
            {
                sendPhotoAndVideoCV.bigVideoNeedTransform = true
            }else {
                sendPhotoAndVideoCV.bigVideoNeedTransform = false
            }
            sendPhotoAndVideoCV.videoTimeLength = videoTimeLength
            let videoPlayWHScale = videoPlayWidth / videoPlayHeight
            if bigVideoIsOriginalSize == true {
                if videoPlayWHScale >= 1//宽大于高,不做处理
                {
                    sendPhotoAndVideoCV.bigVideoIsOriginalSize = true
                    sendPhotoAndVideoCV.X = 0
                    sendPhotoAndVideoCV.Y = 0
                    sendPhotoAndVideoCV.W = 1
                    sendPhotoAndVideoCV.H = 1
                }else {//高大于宽，需要剪切
                    sendPhotoAndVideoCV.videoPlayWHScale = videoPlayWHScale + 0.18
                    sendPhotoAndVideoCV.bigVideoIsOriginalSize = false
                    sendPhotoAndVideoCV.X = 0
                    sendPhotoAndVideoCV.Y = contractRange(N: videoScrollEndPointY / videoPlayHeight)
                    sendPhotoAndVideoCV.W = 1
                    sendPhotoAndVideoCV.H = contractRange(N: kScreenWidth / videoPlayHeight)
                }
            }else {
                sendPhotoAndVideoCV.videoPlayWHScale = 1
                sendPhotoAndVideoCV.bigVideoIsOriginalSize = false
                
                sendPhotoAndVideoCV.X = contractRange(N: videoScrollEndPointX/videoPlayWidth)
                sendPhotoAndVideoCV.Y = contractRange(N: videoScrollEndPointY/videoPlayHeight)
                sendPhotoAndVideoCV.W = contractRange(N: kScreenWidth/videoPlayWidth)
                sendPhotoAndVideoCV.H = contractRange(N: kScreenWidth/videoPlayHeight)
            }
        }
        let navigationController = UINavigationController(rootViewController: sendPhotoAndVideoCV)
        present(navigationController, animated: true, completion: nil)
    }

    // MARK: - Lazy Load
    
    fileprivate lazy var popWindow:UIWindow = {
        let popWindow: UIWindow = UIApplication.shared.windows.last!
        popWindow.backgroundColor = .clear
        return popWindow
    }()
    
    fileprivate lazy var popView:UIView = {
        let popView = UIView()
        popView.backgroundColor = .clear
        
        let label: UILabel = UILabel()
        label.text = "请上传3~60秒的视频哦"
        label.textColor = BLACK
        label.font = UIFont.systemFont(ofSize: 12)
        label.frame = CGRect(x: 0, y: -3, width: 150, height: 45)
        label.textAlignment = .center
        
        popView.addSubview(label)
        return popView
    }()
    
    fileprivate lazy var popBagImageView: UIImageView = {
        let popBagImageView = UIImageView()
        self.popView.insertSubview(popBagImageView, at: 0)
        return popBagImageView
    }()
    
    private lazy var videoView:UIView = {
        let videoView = UIView(frame: CGRect(x: 0, y: 0, width: kScreenWidth, height: kScreenWidth))
        videoView.isUserInteractionEnabled = true
        return videoView
    }()
    
    private lazy var collectionView:UICollectionView = {
        let margen:CGFloat = 2.0
        
        //flowLayout
        let flowLayout = UICollectionViewFlowLayout()
        let width = (kScreenWidth - 3 * margen)/4.0
        flowLayout.itemSize = CGSize(width: width, height: width)
        flowLayout.minimumLineSpacing = margen
        flowLayout.minimumInteritemSpacing = margen
        
        //此处用自动布局，让其一直粘着底部
        let collectionView = self.collectionView1
        collectionView?.collectionViewLayout = flowLayout
        collectionView?.backgroundColor = UIColor.white
        collectionView?.delegate = self
        collectionView?.dataSource = self
        
        collectionView?.register(MUAddPVCollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        if self.fetchResult == nil {
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            self.fetchResult = PHAsset.fetchAssets(with: allPhotosOptions)
        }
        return collectionView!
    }()
}

//MARK: UIScrollViewDelegate
extension MUAddPVViewController: UIScrollViewDelegate
{
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        historyY = scrollView.contentOffset.y
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (scrollView.contentOffset.y < historyY) {//collectionView向下滑动
            if(historyY == 0.0){// 到顶部
                self.middleHeight.constant = middleHeightConstantMax
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.layoutIfNeeded()
                })
            }
        }
        videoScrollEndPointX = scrollView.contentOffset.x
        videoScrollEndPointY = scrollView.contentOffset.y
//        print(videoScrollEndPointX, videoScrollEndPointY)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return bigImageView
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        
        bigImageViewFinishScale = scale
        setImageviewCenterInScrollView(scrollView: scrollView)
    }
}


// MARK: UICollectionViewDataSource

extension MUAddPVViewController: UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let asset = fetchResult.object(at: indexPath.item)
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? MUAddPVCollectionViewCell
            else { fatalError("unexpected cell in collection view") }
        
        cell.representedAssetIdentifier = asset.localIdentifier
        
        let SomeSize = CGSize(width: kScreenWidth/3.0, height: kScreenWidth/3.0)
        
        imageManager.requestImage(for: asset, targetSize: SomeSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
            if cell.representedAssetIdentifier == asset.localIdentifier {
                cell.myImageView.image = image
                
                let timeStamp = lroundf(Float(asset.duration))
                let s = timeStamp % 60
                let m = (timeStamp - s) / 60 % 60
                let time = String(format: "%.2d:%.2d", m, s)
                
                cell.videoTimeLabel.text = time
            }
            if asset.mediaType == .video
            {
                cell.videoTimeLabel.isHidden = false
            }else {
                cell.videoTimeLabel.isHidden = true
            }
        })
        return cell
    }
}

// MARK: UICollectionViewDelegate
extension MUAddPVViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt IndexPath: IndexPath) {
        
        let asset = fetchResult.object(at: IndexPath.item)
        self.selectedType = asset.mediaType.rawValue
        
        self.middleHeight.constant = middleHeightConstantMax
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
            collectionView.scrollToItem(at: IndexPath, at: UICollectionViewScrollPosition.top, animated: false)
        })
        
        if asset.mediaType == .image
        {
            self.nextBtn?.isEnabled = true
            let SomeSize = CGSize(width: kScreenWidth*2, height: kScreenWidth*2)
            imageManager.requestImage(for: asset, targetSize: SomeSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
                
                self.bigImageView?.isHidden = false
                self.bigVideoView?.isHidden = true
                
                // 设置最大和最小的缩放比例
                self.topScrollView?.maximumZoomScale = 2.5
                self.topScrollView?.minimumZoomScale = 0.8
                
                self.bigOriginalImage = image
                self.setupBigImageView(image: image!)
            })
        }else if asset.mediaType == .video {
            //获得点击视频的路径
            imageManager.requestAVAsset(forVideo: asset, options: nil) { (AVAsset, audioMix, info) in
                guard let myAsset = AVAsset as? AVURLAsset else {
                    return
                }
                self.videoPathURL = myAsset.url
                self.videoTimeLength = lroundf(Float(asset.duration))
                
                //限定视频时长
                if (self.videoTimeLength <= 3) || (self.videoTimeLength > 60)
                {
                    DispatchQueue.main.async {
                        
                        
                        if IndexPath.row % 4 == 0
                        {
                            self.popView.frame = CGRect(x: 0, y: self.middleView.y - 15, width: 150, height: 45)
                            self.popBagImageView.image = UIImage(named: "contractBagImageLeft")
                            
                        }else if IndexPath.row % 4 == 3
                        {
                            self.popView.frame = CGRect(x: kScreenWidth - 150, y: self.middleView.y - 15, width: 150, height: 45)
                            self.popBagImageView.image = UIImage(named: "contractBagImageRight")
                        }else {
                            self.popView.frame = CGRect(x: 0, y: self.middleView.y - 15, width: 150, height: 45)
                            self.popView.center.x = (CGFloat(IndexPath.row % 4) + 0.5) * (kScreenWidth - 3 * 2)/4.0
                            self.popBagImageView.image = UIImage(named: "contractBagImageMiddle")
                        }
                        self.popBagImageView.frame = self.popView.bounds
                        self.popWindow.addSubview(self.popView)
                        self.nextBtn?.isEnabled = false
                    }
                    
                    let time: TimeInterval = 1.5
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + time) {
                        self.popView.removeFromSuperview()
                        self.popWindow.removeFromSuperview()
                    }
                    
                }else {
                    DispatchQueue.main.async {
                        self.popView.removeFromSuperview()
                        self.popWindow.removeFromSuperview()
                        self.nextBtn?.isEnabled = true
                    }
                    
                }
                
                //生成视频截图
                let generator = AVAssetImageGenerator(asset: myAsset)
                generator.appliesPreferredTrackTransform = true
                let time = CMTimeMakeWithSeconds(0.0,600)
                var actualTime:CMTime = CMTimeMake(0,0)
                let imageRef:CGImage = try! generator.copyCGImage(at: time, actualTime: &actualTime)
                let frameImg = UIImage(cgImage: imageRef)
                
                //显示截图
                self.bigVideoImage = frameImg
                
            }
            
            self.bigImageView?.isHidden = true
            self.bigVideoView?.isHidden = false
            // 视频不需要缩放
            topScrollView?.maximumZoomScale = 1
            topScrollView?.minimumZoomScale = 1
            bigVideoOriginalSizeWidth = asset.pixelWidth
            bigVideoOriginalSizeHeight = asset.pixelHeight
            setupBigVideoView(width: asset.pixelWidth, height: asset.pixelHeight)
            
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            // Request an AVPlayerItem for the displayed PHAsset and set up a layer for playing it.
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options, resultHandler: { playerItem, info in
                DispatchQueue.main.sync {
                    guard self.playerLayer == nil else { return }
                    // Create an AVPlayer and AVPlayerLayer with the AVPlayerItem.
                    let player = AVPlayer(playerItem: playerItem)
                    let playerLayer = AVPlayerLayer(player: player)
                    
                    // Configure the AVPlayerLayer and add it to the view.
                    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect
                    playerLayer.frame = (self.bigVideoView?.layer.bounds)!
                    self.bigVideoView?.layer.addSublayer(playerLayer)
                    player.play()
                    // Refer to the player layer so we can remove it later.
                    self.bigVideoPlayer = player
                    self.playerLayer = playerLayer
                }
            })
        }
    }
    
    //大屏幕video
    private func setupBigVideoView(width: Int , height: Int)
    {
        //首先把之前的图片移除
        self.bigImageView?.image = nil
        //首先把之前的player移除
        bigVideoPlayer?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        
        //添加新的video
        let widthScale = self.topScrollView.frame.size.width/CGFloat(width)/1.0
        let heightScale = self.topScrollView.frame.size.height/CGFloat(height)/1.0
        
        //max代表是大视频(需要剪切)，min代表是原视频(小)
        let scale = max(widthScale, heightScale)
        bigVideoIsOriginalSize = false
        
        videoPlayWidth = CGFloat(width) * scale
        videoPlayHeight = CGFloat(height) * scale
        
        self.bigVideoView?.frame = CGRect(x: 0, y: 0, width: videoPlayWidth, height: videoPlayHeight)
        
        //contentSize必须设置,否则无法滚动，当前设置为图片大小
        //设置这两个内容相等
        self.topScrollView.contentSize = (self.bigVideoView?.frame.size)!
        
        setViewCenterInScrollView(view: bigVideoView!, scrollView: topScrollView)
        
        //自适应
        self.bigVideoView?.contentMode = UIViewContentMode.scaleAspectFill
    }

    //设置图片的尺寸
    private func setupBigImageView(image: UIImage)
    {
        //把之前的图片移除
        self.bigImageView?.image = nil
        
        //把之前的player移除
        bigVideoPlayer?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        
        //添加新的image图片
        self.bigImageView?.image = image
        
        let widthScale = self.topScrollView.frame.size.width/(self.bigImageView?.image!.size.width)!/1.0
        let heightScale = self.topScrollView.frame.size.height/(self.bigImageView?.image!.size.height)!/1.0
        let scale = max(widthScale, heightScale)
        
        let w = (self.bigImageView?.image!.size.width)! * scale
        let h = (self.bigImageView?.image!.size.height)! * scale
        
        self.bigImageView?.frame = CGRect(x: 0, y: 0, width: w, height: h)
        
        //contentSize必须设置,否则无法滚动，当前设置为图片大小
        //设置这两个内容相等
        self.topScrollView.contentSize = (self.bigImageView?.frame.size)!
        self.bigImageView?.isUserInteractionEnabled = true
        
        setViewCenterInScrollView(view: bigImageView!, scrollView: topScrollView)
        
        //自适应
        self.bigImageView?.contentMode = UIViewContentMode.scaleAspectFill
    }
}
