//
//  FloatingPoint+Extension.swift
//  ARMusic
//
//  Created by Valerian Clerc on 10/26/19.
//  Copyright © 2019 Valerian Clerc. All rights reserved.
//

import Foundation

extension FloatingPoint {
    func toRadians() -> Self {
        return self * .pi / 180
    }

    func toDegrees() -> Self {
        return self * 180 / .pi
    }
}
