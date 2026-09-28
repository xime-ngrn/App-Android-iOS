import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Filtros disponibles para aplicar a las fotos capturadas, usando
/// Core Image. "Original" no aplica ningun filtro.
enum PhotoFilter: String, CaseIterable, Identifiable {
    case original = "Original"
    case blancoYNegro = "Blanco y Negro"
    case sepia = "Sepia"
    case vivido = "Vivido"

    var id: String { rawValue }

    func apply(to image: UIImage) -> UIImage {
        guard self != .original, let ciImage = CIImage(image: image) else { return image }
        let context = CIContext()
        var output: CIImage = ciImage

        switch self {
        case .original:
            break
        case .blancoYNegro:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = ciImage
            output = filter.outputImage ?? ciImage
        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = ciImage
            filter.intensity = 0.85
            output = filter.outputImage ?? ciImage
        case .vivido:
            let filter = CIFilter.vibrance()
            filter.inputImage = ciImage
            filter.amount = 0.8
            output = filter.outputImage ?? ciImage
        }

        guard let cgImage = context.createCGImage(output, from: ciImage.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
