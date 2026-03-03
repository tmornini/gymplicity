import SwiftUI

// MARK: - Poses

enum MascotPose {
    case lifting
    case celebrating
    case resting
    case curling
    case stretching
    case spotting
    case thinking
    case deadlifting
    case walking
    case waving
}

// MARK: - MascotView

struct MascotView: View {
    let pose: MascotPose
    var color: Color = GymColors.chalk

    var body: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(
                lineWidth: size.width * 0.045,
                lineCap: .round,
                lineJoin: .round
            )

            let headRadius = size.width * 0.09
            let points = posePoints(for: pose, in: size)

            // Head
            let headPath = Path(ellipseIn: CGRect(
                x: points.head.x - headRadius,
                y: points.head.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            ))
            context.stroke(headPath, with: .color(color), style: stroke)

            // Body
            var bodyPath = Path()
            bodyPath.move(to: points.neck)
            bodyPath.addLine(to: points.hip)
            context.stroke(bodyPath, with: .color(color), style: stroke)

            // Left leg
            var leftLeg = Path()
            leftLeg.move(to: points.hip)
            leftLeg.addLine(to: points.leftFoot)
            context.stroke(leftLeg, with: .color(color), style: stroke)

            // Right leg
            var rightLeg = Path()
            rightLeg.move(to: points.hip)
            rightLeg.addLine(to: points.rightFoot)
            context.stroke(rightLeg, with: .color(color), style: stroke)

            // Left arm
            var leftArm = Path()
            leftArm.move(to: points.shoulder)
            leftArm.addLine(to: points.leftHand)
            context.stroke(leftArm, with: .color(color), style: stroke)

            // Right arm
            var rightArm = Path()
            rightArm.move(to: points.shoulder)
            rightArm.addLine(to: points.rightHand)
            context.stroke(rightArm, with: .color(color), style: stroke)

            // Barbell (if present)
            if let barbell = points.barbell {
                drawBarbell(context: context, barbell: barbell, size: size, color: color, stroke: stroke)
            }
        }
        .aspectRatio(0.6, contentMode: .fit)
    }

    private func drawBarbell(context: GraphicsContext, barbell: BarbellPoints, size: CGSize, color: Color, stroke: StrokeStyle) {
        // Bar
        var bar = Path()
        bar.move(to: barbell.left)
        bar.addLine(to: barbell.right)
        context.stroke(bar, with: .color(color), style: stroke)

        // Plates (small circles at ends)
        let plateRadius = size.width * 0.035
        let leftPlate = Path(ellipseIn: CGRect(
            x: barbell.left.x - plateRadius,
            y: barbell.left.y - plateRadius,
            width: plateRadius * 2,
            height: plateRadius * 2
        ))
        context.fill(leftPlate, with: .color(color))
        let rightPlate = Path(ellipseIn: CGRect(
            x: barbell.right.x - plateRadius,
            y: barbell.right.y - plateRadius,
            width: plateRadius * 2,
            height: plateRadius * 2
        ))
        context.fill(rightPlate, with: .color(color))
    }
}

// MARK: - Pose Geometry

private struct PosePoints {
    let head: CGPoint
    let neck: CGPoint
    let shoulder: CGPoint
    let hip: CGPoint
    let leftHand: CGPoint
    let rightHand: CGPoint
    let leftFoot: CGPoint
    let rightFoot: CGPoint
    let barbell: BarbellPoints?
}

private struct BarbellPoints {
    let left: CGPoint
    let right: CGPoint
}

private func posePoints(for pose: MascotPose, in size: CGSize) -> PosePoints {
    let w = size.width
    let h = size.height
    let cx = w * 0.5

    switch pose {
    case .lifting:
        // Classic icon: barbell overhead
        let head = CGPoint(x: cx, y: h * 0.18)
        let neck = CGPoint(x: cx, y: h * 0.24)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.25, y: h * 0.08),
            rightHand: CGPoint(x: w * 0.75, y: h * 0.08),
            leftFoot: CGPoint(x: w * 0.35, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.65, y: h * 0.82),
            barbell: BarbellPoints(
                left: CGPoint(x: w * 0.12, y: h * 0.08),
                right: CGPoint(x: w * 0.88, y: h * 0.08)
            )
        )

    case .celebrating:
        // Arms up in V, no barbell
        let head = CGPoint(x: cx, y: h * 0.18)
        let neck = CGPoint(x: cx, y: h * 0.24)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.22, y: h * 0.10),
            rightHand: CGPoint(x: w * 0.78, y: h * 0.10),
            leftFoot: CGPoint(x: w * 0.35, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.65, y: h * 0.82),
            barbell: nil
        )

    case .resting:
        // Standing relaxed, barbell at feet
        let head = CGPoint(x: cx, y: h * 0.18)
        let neck = CGPoint(x: cx, y: h * 0.24)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.32, y: h * 0.50),
            rightHand: CGPoint(x: w * 0.68, y: h * 0.50),
            leftFoot: CGPoint(x: w * 0.38, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.62, y: h * 0.82),
            barbell: BarbellPoints(
                left: CGPoint(x: w * 0.15, y: h * 0.88),
                right: CGPoint(x: w * 0.85, y: h * 0.88)
            )
        )

    case .curling:
        // One arm doing a bicep curl with barbell
        let head = CGPoint(x: cx, y: h * 0.18)
        let neck = CGPoint(x: cx, y: h * 0.24)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.32, y: h * 0.50),
            rightHand: CGPoint(x: w * 0.65, y: h * 0.20),
            leftFoot: CGPoint(x: w * 0.38, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.62, y: h * 0.82),
            barbell: BarbellPoints(
                left: CGPoint(x: w * 0.55, y: h * 0.20),
                right: CGPoint(x: w * 0.78, y: h * 0.20)
            )
        )

    case .stretching:
        // Side bend, one arm overhead
        let head = CGPoint(x: w * 0.45, y: h * 0.16)
        let neck = CGPoint(x: w * 0.47, y: h * 0.23)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.30, y: h * 0.08),
            rightHand: CGPoint(x: w * 0.68, y: h * 0.50),
            leftFoot: CGPoint(x: w * 0.38, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.62, y: h * 0.82),
            barbell: nil
        )

    case .spotting:
        // Arms reaching forward
        let head = CGPoint(x: cx, y: h * 0.18)
        let neck = CGPoint(x: cx, y: h * 0.24)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.78, y: h * 0.32),
            rightHand: CGPoint(x: w * 0.78, y: h * 0.28),
            leftFoot: CGPoint(x: w * 0.35, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.55, y: h * 0.82),
            barbell: nil
        )

    case .thinking:
        // Hand on chin, barbell leaning nearby
        let head = CGPoint(x: cx, y: h * 0.18)
        let neck = CGPoint(x: cx, y: h * 0.24)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.32, y: h * 0.50),
            rightHand: CGPoint(x: w * 0.55, y: h * 0.17),
            leftFoot: CGPoint(x: w * 0.38, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.62, y: h * 0.82),
            barbell: BarbellPoints(
                left: CGPoint(x: w * 0.78, y: h * 0.40),
                right: CGPoint(x: w * 0.85, y: h * 0.88)
            )
        )

    case .deadlifting:
        // Bent over, pulling barbell up
        let head = CGPoint(x: w * 0.60, y: h * 0.22)
        let neck = CGPoint(x: w * 0.55, y: h * 0.28)
        let shoulder = CGPoint(x: cx, y: h * 0.35)
        let hip = CGPoint(x: w * 0.42, y: h * 0.50)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.55, y: h * 0.55),
            rightHand: CGPoint(x: w * 0.65, y: h * 0.55),
            leftFoot: CGPoint(x: w * 0.30, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.52, y: h * 0.82),
            barbell: BarbellPoints(
                left: CGPoint(x: w * 0.20, y: h * 0.55),
                right: CGPoint(x: w * 0.80, y: h * 0.55)
            )
        )

    case .walking:
        // Mid-stride with barbell on shoulders
        let head = CGPoint(x: cx, y: h * 0.18)
        let neck = CGPoint(x: cx, y: h * 0.24)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.30, y: h * 0.30),
            rightHand: CGPoint(x: w * 0.70, y: h * 0.30),
            leftFoot: CGPoint(x: w * 0.28, y: h * 0.85),
            rightFoot: CGPoint(x: w * 0.72, y: h * 0.78),
            barbell: BarbellPoints(
                left: CGPoint(x: w * 0.15, y: h * 0.30),
                right: CGPoint(x: w * 0.85, y: h * 0.30)
            )
        )

    case .waving:
        // One arm up waving
        let head = CGPoint(x: cx, y: h * 0.18)
        let neck = CGPoint(x: cx, y: h * 0.24)
        let shoulder = CGPoint(x: cx, y: h * 0.30)
        let hip = CGPoint(x: cx, y: h * 0.55)
        return PosePoints(
            head: head, neck: neck, shoulder: shoulder, hip: hip,
            leftHand: CGPoint(x: w * 0.32, y: h * 0.50),
            rightHand: CGPoint(x: w * 0.75, y: h * 0.10),
            leftFoot: CGPoint(x: w * 0.38, y: h * 0.82),
            rightFoot: CGPoint(x: w * 0.62, y: h * 0.82),
            barbell: nil
        )
    }
}
