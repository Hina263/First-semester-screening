//
//  ImageResizer.swift
//  NAGORI
//
//  M-04 担当: まなと
//  画像方針: 長辺2048px・JPEG品質0.85でリサイズして保存する。
//  jpegData を通すとEXIF（GPS情報を含む）が削除されるので、写真から撮影場所が漏れない。
//

import UIKit

enum ImageResizer {

    static func jpegData(
        from image: UIImage,
        maxLongSide: CGFloat = 2048,
        quality: CGFloat = 0.85
    ) -> Data? {
        let longSide = max(image.size.width, image.size.height)
        let scale = min(1, maxLongSide / longSide)
        let newSize = CGSize(width: image.size.width * scale,
                             height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1   // 端末のRetina倍率を掛けない

        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))   // 画像の向きもここで正規化される
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
