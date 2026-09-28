import UIKit

/// Cache en memoria de miniaturas de imagenes para que la lista de
/// archivos no tenga que releer y redimensionar la imagen cada vez
/// que se redibuja la fila.
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for url: URL) -> UIImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let targetSize = CGSize(width: 80, height: 80)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        cache.setObject(thumbnail, forKey: key)
        return thumbnail
    }
}
