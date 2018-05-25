//
//  MUAddPVCollectionViewCell.swift
//  MU
//
//  Created by shanyazhou on 2016/12/29.
//  Copyright © 2016年 li. All rights reserved.
//

import UIKit

class MUAddPVCollectionViewCell: UICollectionViewCell {
    
    
    var representedAssetIdentifier: String!

    override init(frame: CGRect) {
        
        super.init(frame: frame)
        self.myImageView.frame = CGRect(x:0, y:0, width:frame.size.width, height:frame.size.height)
        self.contentView.addSubview(self.myImageView)
        
        
        let videoTimeLabelHeight: CGFloat = 20.0
        self.videoTimeLabel.frame = CGRect(x:0, y:frame.size.height - videoTimeLabelHeight, width:frame.size.width - 5, height:videoTimeLabelHeight)
        self.videoTimeLabel.textAlignment = NSTextAlignment.right
        self.contentView.addSubview(self.videoTimeLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    var myImageView:UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = UIColor.gray
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    var videoTimeLabel:UILabel = {
        let videoTimeLabel = UILabel()
        videoTimeLabel.textColor = UIColor.white
        videoTimeLabel.font = UIFont.systemFont(ofSize: 10)
        return videoTimeLabel
    }()

}
