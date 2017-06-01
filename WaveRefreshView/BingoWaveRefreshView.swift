//
//  BingoWaveRefreshView.swift
//  WaveRefreshView
//
//  Created by 王昱斌 on 17/5/31.
//  Copyright © 2017年 Qtin. All rights reserved.
//

import UIKit

enum WaveRefreshViewState : Int{
    case stop
    case animating
    case animatingToStopped
}

class BingoWaveRefreshView: UIView {
    private struct BingoWaveRefreshViewData{
        /// 最大波峰
        static var maxVariable : CGFloat = 1.6
        /// 最小波峰
        static var minVariable : CGFloat = 1.0
        /// 最小波峰增量
        static var minStepLength : CGFloat = 0.01
        /// 最大波峰增量
        static var maxStepLength : CGFloat = 0.05
        /// 键值
        static var keyPathsContentOffset = "contentOffset"
    }
    /// 刷新事件
    var actionClosure : (()->())?
    /// 顶部波浪颜色
    var topWaveColor : UIColor? {
        willSet{
            firstWaveLayer.fillColor = newValue!.cgColor
        }
    }
    /// 底部波浪颜色
    var bottomWaveColor : UIColor? {
        willSet{
            secondWaveLayer.fillColor = newValue!.cgColor
        }
    }
    /// 对应scrollView
    fileprivate weak var scrollView : UIScrollView?{
        willSet{
            _cycle = CGFloat(2 * M_PI) / newValue!.frame.size.width;
        }
    }
    
    /// 定时器
    fileprivate var displaylink : CADisplayLink!
    /// 顶部波浪
    fileprivate var firstWaveLayer : CAShapeLayer!
    /// 底部波浪
    fileprivate var secondWaveLayer : CAShapeLayer!
    /// 状态
    fileprivate var state : WaveRefreshViewState! = .stop
    /// 根据scrollView偏移量得出的比例
    fileprivate var _times : NSInteger = 0
    /// 波峰值
    fileprivate var _amplitude : CGFloat = 0
    /// 波浪的周期值
    fileprivate var _cycle : CGFloat = 0
    /// 单位时间平移速率
    fileprivate var _speed : CGFloat = 0
    /// 波浪平移偏移量
    fileprivate var _offsetX : CGFloat = 0
    /// scrollView偏移量
    fileprivate var _offsetY : CGFloat = 0
    /// 计算波峰的比率
    fileprivate var _variable : CGFloat = 0
    /// 波峰至波谷的距离
    fileprivate var _height : CGFloat = 0
    /// 波峰是否增大
    fileprivate var _increase  : Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUI()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - set&get
    func setUI() -> Void {
        displaylink = CADisplayLink(target: self, selector: #selector(displayLinkTric(link:)))
        if #available(iOS 10.0, *) {
            displaylink.preferredFramesPerSecond = 30
        }else {
            displaylink.frameInterval = 2;
        }
        displaylink.add(to: RunLoop.main, forMode: .commonModes)
        displaylink.isPaused = true
        firstWaveLayer = CAShapeLayer()
        firstWaveLayer.fillColor = UIColor.lightGray.cgColor
        secondWaveLayer = CAShapeLayer()
        secondWaveLayer.fillColor = UIColor.white.cgColor
        topWaveColor = UIColor.lightGray
        bottomWaveColor = UIColor.white
        setupProperty()
    }
    func setupProperty() -> Void {
        _speed = 0.5 / CGFloat(M_PI)
        _times = 1
        _amplitude = BingoWaveRefreshViewData.maxVariable
        _variable = BingoWaveRefreshViewData.maxVariable
        _increase = false
    }
    func currentHeight() -> CGFloat {
        if scrollView == nil {
            return 0.0
        }
        return 2 * _height
    }
    
    //MARK: - observe
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if scrollView == nil {
            return
        }
        // FIXME : - 根据自己的需求添加响应的监听
        if let keyPath = keyPath {
            switch keyPath {
            case BingoWaveRefreshViewData.keyPathsContentOffset:
                didChangeContentOffset()
            default:
                return
            }
        }
    }
    /// 注册观察者
    ///
    /// - Parameter scrollView: scrollView description
    func observe(scrollView : UIScrollView) -> Void {
        self.scrollView = scrollView
        self.scrollView?.addObserver(self, forKeyPath: BingoWaveRefreshViewData.keyPathsContentOffset, options: .new, context: nil)
    }
    /// 注销观察者
    ///
    /// - Parameter scrollView: scrollView description
    func removeObserver(scrollView : UIScrollView) -> Void {
        self.scrollView?.removeObserver(self, forKeyPath: BingoWaveRefreshViewData.keyPathsContentOffset)
    }
    
    //MARK: - Event
    /// 响应scrollView偏移量的变化
    func didChangeContentOffset() -> Void {
        guard let scrollView = self.scrollView else {
            return
        }
        let offset : CGFloat = (-scrollView.contentOffset.y - scrollView.contentInset.top)
        if offset < 0.0{
            _times = 0
        }
        _times = NSInteger(offset / 10) + 1
        
        if offset == 0.0 && scrollView.isDecelerating {
            animatingStopWave()
        }
        if offset >= 0.0 && !scrollView.isDecelerating && state != .animating && scrollView.isTracking{
            stateWave()
        }
    }
    
    /// 刷新波峰
    func configWaveAmplitude() -> Void {
        if (_increase) {
            _variable += BingoWaveRefreshViewData.minStepLength
        } else {
            let minus : CGFloat = self.state == .animatingToStopped ? BingoWaveRefreshViewData.maxStepLength : BingoWaveRefreshViewData.minStepLength
            _variable -= minus;
            if (_variable <= 0.00) {
                self.stopWave()
            }
        }
        if (_variable <= BingoWaveRefreshViewData.minVariable) {
            _increase = !(self.state == .animatingToStopped)
        }
        
        if (_variable >= BingoWaveRefreshViewData.maxVariable) {
            _increase = false
        }
        // self.amplitude = self.variable*self.times;
        if (_times >= 7) {
            _times = 7;
        }
        _amplitude = _variable * CGFloat( _times)
        _height = BingoWaveRefreshViewData.maxVariable * CGFloat( _times)
    }
    /// 刷新偏移量
    func configWaveOffset() -> Void {
        _offsetX += _speed;
        _offsetY =  currentHeight() - _amplitude;
    }
    /// 刷新视图位置
    func configViewFrame() -> Void {
        if let scrollView = self.scrollView {
            let width = scrollView.bounds.size.width
            let height = currentHeight()
            self.frame = CGRect(x: 0, y: -height, width: width, height: height)
        }
    }
    /// 刷新顶部波浪
    func configFirstWaveLayerPath() -> Void {
        guard let scrollView = scrollView else {
            return
        }
        var y = _offsetY
        let path : CGMutablePath = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: y))
        let waveWidth : CGFloat = scrollView.frame.size.width
        for x in 0...Int(waveWidth) {
            y = _amplitude * sin(_cycle * CGFloat(x) + _offsetX) + _offsetY
            path.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }
        path.addLine(to: CGPoint(x: waveWidth, y: self.frame.size.height))
        path.addLine(to: CGPoint(x: 0, y: self.frame.size.height))
        path.closeSubpath()
        firstWaveLayer.path = path
    }
    /// 刷新底部波浪
    func configSecondWaveLayerPath() -> Void {
        guard let scrollView = scrollView else {
            return
        }
        var y = _offsetY
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: y))
        let forward = CGFloat(M_PI) / (_cycle * 4.0)
        let waveWidth : CGFloat = scrollView.frame.size.width
        for x in 0...Int(waveWidth) {
            y = _amplitude * cos(_cycle * CGFloat(x) + _offsetX  + forward) + _offsetY
            path.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }
        path.addLine(to: CGPoint(x: waveWidth, y: self.frame.size.height))
        path.addLine(to: CGPoint(x: 0, y: self.frame.size.height))
        path.closeSubpath()
        secondWaveLayer.path = path
    }
    //MARK: - animation
    /// 开始动画
    func stateWave() -> Void {
        if self.displaylink.isPaused == false{
            self.firstWaveLayer.path = nil
            self.secondWaveLayer.path = nil
            self.firstWaveLayer.removeFromSuperlayer()
            self.secondWaveLayer.removeFromSuperlayer()
        }
        setupProperty()
        self.state = .animating
        self.layer.addSublayer(self.firstWaveLayer)
        self.layer.addSublayer(self.secondWaveLayer)
        self.displaylink.isPaused = false
    }
    /// 动画停止中
    func animatingStopWave() -> Void {
        self.state = .animatingToStopped
        if let actionClosure = self.actionClosure {
            actionClosure()
        }
    }
    /// 动画停止
    func stopWave() -> Void {
        self.state = .stop
        self.displaylink.isPaused = true
        self.firstWaveLayer.path = nil
        self.secondWaveLayer.path = nil
        self.firstWaveLayer.removeFromSuperlayer()
        self.secondWaveLayer.removeFromSuperlayer()
    }
    
    //MARK: - timer
    func displayLinkTric(link : CADisplayLink) -> Void {
        configWaveAmplitude()
        configWaveOffset()
        configViewFrame()
        configFirstWaveLayerPath()
        configSecondWaveLayerPath()
    }
    func invalidateWave() -> Void {
        self.displaylink.invalidate()
    }
}

extension UIScrollView{
    private struct AssociatedKeys {
        static var pullToRefreshViewKey = "pullToRefreshViewKey"
    }
    var pullToRefreshView : BingoWaveRefreshView?{
        set{
            objc_setAssociatedObject(self, AssociatedKeys.pullToRefreshViewKey, (newValue as BingoWaveRefreshView?), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get{
            return objc_getAssociatedObject(self, &AssociatedKeys.pullToRefreshViewKey) as? BingoWaveRefreshView
        }
    }
}

extension UIScrollView{
    func addRefreshView(actionClosure : @escaping (()->())) -> Void {
        let waveView = BingoWaveRefreshView()
        self.addSubview(waveView)
        self.pullToRefreshView = waveView
        waveView.actionClosure = actionClosure
        waveView.observe(scrollView: self)
    }
    func removeRefreshView() -> Void {
        if let pullToRefreshView = pullToRefreshView {
            pullToRefreshView.invalidateWave()
            pullToRefreshView.removeObserver(scrollView: self)
            pullToRefreshView.removeFromSuperview()
        }
    }
    func setTopLayer(fillColor : UIColor) -> Void {
        pullToRefreshView?.topWaveColor = fillColor
    }
    func setBottomLayer(fillColor : UIColor) -> Void {
        pullToRefreshView?.topWaveColor = fillColor
    }
}
