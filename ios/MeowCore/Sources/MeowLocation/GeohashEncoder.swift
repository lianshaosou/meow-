import Foundation
import MeowDomain

public struct GeohashEncoder {
    private let alphabet = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    public init() {}

    public func encode(_ coordinate: Coordinate, precision: Int = 7) -> RegionCell {
        precondition(precision > 0 && precision <= 12, "precision must be in 1...12")

        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var isEvenBit = true
        var currentBits = 0
        var bitCount = 0
        var hash = ""

        while hash.count < precision {
            if isEvenBit {
                let mid = (lonRange.0 + lonRange.1) / 2
                if coordinate.longitude >= mid {
                    currentBits = (currentBits << 1) | 1
                    lonRange.0 = mid
                } else {
                    currentBits = currentBits << 1
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if coordinate.latitude >= mid {
                    currentBits = (currentBits << 1) | 1
                    latRange.0 = mid
                } else {
                    currentBits = currentBits << 1
                    latRange.1 = mid
                }
            }

            isEvenBit.toggle()
            bitCount += 1

            if bitCount == 5 {
                hash.append(alphabet[currentBits])
                bitCount = 0
                currentBits = 0
            }
        }

        return RegionCell(geohash: hash, precision: precision)
    }
}
