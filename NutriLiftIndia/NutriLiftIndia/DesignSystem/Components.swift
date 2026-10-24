import SwiftUI

// MARK: - Cards

private struct AppCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

private struct GradientCardModifier: ViewModifier {
    let gradient: LinearGradient
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(gradient, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

extension View {
    /// Rounded white (or dark) card with a soft shadow.
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardModifier(padding: padding))
    }

    /// Rounded card filled with a gradient. Use white text on top.
    func gradientCard(_ gradient: LinearGradient = Theme.brandGradient, padding: CGFloat = 16) -> some View {
        modifier(GradientCardModifier(gradient: gradient, padding: padding))
    }
}

// MARK: - Buttons

struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.brandGradient
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(gradient, in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.saffron

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, weight: .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tint.opacity(0.14), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GradientButtonStyle {
    static var gradient: GradientButtonStyle { GradientButtonStyle() }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: SoftButtonStyle { SoftButtonStyle() }
}

// MARK: - Emoji choices

struct EmojiOption<Value: Hashable>: Identifiable {
    let value: Value
    let emoji: String
    let title: String
    var subtitle: String? = nil

    var id: Value { value }
}

/// Large, tappable cards for single-select choices. One column gives full-width rows.
struct EmojiChoiceGrid<Value: Hashable>: View {
    let options: [EmojiOption<Value>]
    @Binding var selection: Value
    var columns: Int = 2

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: max(1, columns)),
            spacing: 12
        ) {
            ForEach(options) { option in
                EmojiChoiceCard(
                    option: option,
                    isSelected: option.value == selection,
                    horizontal: columns == 1
                ) {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = option.value
                    }
                }
            }
        }
    }
}

struct EmojiChoiceCard<Value: Hashable>: View {
    let option: EmojiOption<Value>
    let isSelected: Bool
    var horizontal: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if horizontal {
                    HStack(spacing: 14) {
                        emojiView
                        textStack(alignment: .leading)
                        Spacer(minLength: 0)
                        checkmark
                    }
                } else {
                    VStack(spacing: 8) {
                        emojiView
                        textStack(alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .topTrailing) { checkmark }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? Theme.cardSelected : Theme.card,
                in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Color.primary.opacity(0.06)), lineWidth: isSelected ? 2.5 : 1)
            }
            .scaleEffect(isSelected ? 1.02 : 1)
            .shadow(color: .black.opacity(isSelected ? 0.10 : 0.04), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text([option.title, option.subtitle].compactMap { $0 }.joined(separator: ". ")))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var emojiView: some View {
        Text(option.emoji)
            .font(.system(size: horizontal ? 32 : 40))
            .accessibilityHidden(true)
    }

    private func textStack(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(option.title)
                .font(.rounded(.headline, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(alignment == .leading ? .leading : .center)
            if let subtitle = option.subtitle {
                Text(subtitle)
                    .font(.rounded(.caption))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(alignment == .leading ? .leading : .center)
            }
        }
    }

    @ViewBuilder
    private var checkmark: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Theme.chilli)
                .font(.title3)
                .transition(.scale.combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }
}

/// A horizontally scrolling row of pill buttons, for compact choices such as meal type or chart range.
struct EmojiSegmented<Value: Hashable>: View {
    let options: [EmojiOption<Value>]
    @Binding var selection: Value

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    let isSelected = option.value == selection
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = option.value
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if !option.emoji.isEmpty {
                                Text(option.emoji).accessibilityHidden(true)
                            }
                            Text(option.title)
                        }
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                Capsule().fill(Theme.brandGradient)
                            } else {
                                Capsule().fill(Theme.card)
                            }
                        }
                        .overlay {
                            Capsule().strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Number inputs

/// Big tap-to-type number with a slider and fine-tune buttons. For height, weight and similar values.
struct BigNumberInput: View {
    let emoji: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var unit: String
    var fractionDigits: Int = 0

    @FocusState private var isEditing: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(emoji).accessibilityHidden(true)
                Text(title)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                nudgeButton(systemImage: "minus", delta: -step)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("0", value: $value, format: .number.precision(.fractionLength(0...fractionDigits)))
                        .keyboardType(fractionDigits > 0 ? .decimalPad : .numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .focused($isEditing)
                        .frame(minWidth: 90, maxWidth: 150)
                        .accessibilityLabel(title)
                    Text(unit)
                        .font(.rounded(.title3, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                nudgeButton(systemImage: "plus", delta: step)
            }

            Slider(value: sliderBinding, in: range, step: step)
                .tint(Theme.saffron)
                .accessibilityLabel(title)

            HStack {
                Text("\(format(range.lowerBound)) \(unit)")
                Spacer()
                Text("\(format(range.upperBound)) \(unit)")
            }
            .font(.rounded(.caption2))
            .foregroundStyle(.tertiary)
        }
        .appCard()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                // Only the focused field shows "Done", so two inputs on one page don't double up.
                if isEditing {
                    Spacer()
                    Button("Done") { isEditing = false }
                }
            }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { value = min(max(value, range.lowerBound), range.upperBound) }
        }
    }

    /// The slider can't show a value outside its range, so clamp what it reads.
    private var sliderBinding: Binding<Double> {
        Binding(
            get: { min(max(value, range.lowerBound), range.upperBound) },
            set: { newValue in
                if newValue != value { Haptics.selection() }
                value = newValue
            }
        )
    }

    private func nudgeButton(systemImage: String, delta: Double) -> some View {
        Button {
            Haptics.tap()
            let next = ((value + delta) * 100).rounded() / 100
            value = min(max(next, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Theme.saffron)
                .frame(width: 44, height: 44)
                .background(Theme.saffron.opacity(0.14), in: Circle())
        }
        .accessibilityLabel(delta < 0 ? "Decrease \(title)" : "Increase \(title)")
    }

    private func format(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(0...fractionDigits)))
    }
}

/// Big round +/- stepper with a large value in the middle. For age, quantities and similar.
struct BigStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var unit: String = ""
    var fractionDigits: Int = 0

    var body: some View {
        HStack(spacing: 20) {
            button("minus", delta: -step)
            VStack(spacing: 0) {
                Text(value.formatted(.number.precision(.fractionLength(0...fractionDigits))))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 90)
            button("plus", delta: step)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value.formatted()) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(step)
            case .decrement: nudge(-step)
            @unknown default: break
            }
        }
    }

    private func nudge(_ delta: Double) {
        let next = ((value + delta) * 100).rounded() / 100
        withAnimation(.snappy) {
            value = min(max(next, range.lowerBound), range.upperBound)
        }
    }

    private func button(_ systemImage: String, delta: Double) -> some View {
        Button {
            Haptics.tap()
            nudge(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Theme.brandGradient, in: Circle())
        }
        .accessibilityHidden(true)
    }
}

/// Compact +/- field with a typed value, sized to sit two across (e.g. weight and reps while logging a set).
/// Buttons use the plain style so several can live in one List row.
struct CompactStepperField: View {
    let title: String
    @Binding var value: Double
    var step: Double = 1
    var range: ClosedRange<Double> = 0...1000
    var unit: String = ""
    var fractionDigits: Int = 1

    @FocusState private var isEditing: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.rounded(.caption, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                nudge("minus", -step)
                TextField("0", value: clamped($value, to: range), format: .number.precision(.fractionLength(0...fractionDigits)))
                    .keyboardType(fractionDigits > 0 ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.center)
                    .font(.rounded(.title2, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: 48)
                    .focused($isEditing)
                    .accessibilityLabel(title)
                nudge("plus", step)
            }
            if !unit.isEmpty {
                Text(unit)
                    .font(.rounded(.caption2))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Theme.saffron.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isEditing {
                    Spacer()
                    Button("Done") { isEditing = false }
                }
            }
        }
    }

    private func nudge(_ systemImage: String, _ delta: Double) -> some View {
        Button {
            Haptics.tap()
            let next = ((value + delta) * 100).rounded() / 100
            value = min(max(next, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.saffron)
                .frame(width: 34, height: 34)
                .background(Theme.saffron.opacity(0.16), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? "Decrease \(title)" : "Increase \(title)")
    }
}

/// A labelled number row for forms. Replaces the copies of this helper that used to live in each screen.
struct LabeledNumberField: View {
    let title: String
    @Binding var value: Double
    var unit: String? = nil
    var emoji: String? = nil
    /// Typed values are clamped to this range, which also keeps absurd input from breaking later maths.
    var range: ClosedRange<Double> = 0...100_000

    @FocusState private var isEditing: Bool

    init(_ title: String, value: Binding<Double>, unit: String? = nil, emoji: String? = nil, range: ClosedRange<Double> = 0...100_000) {
        self.title = title
        self._value = value
        self.unit = unit
        self.emoji = emoji
        self.range = range
    }

    var body: some View {
        HStack(spacing: 10) {
            if let emoji {
                Text(emoji).accessibilityHidden(true)
            }
            Text(title)
            Spacer(minLength: 8)
            TextField("0", value: clamped($value, to: range), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.rounded(.body, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 100)
                .background(Theme.saffron.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($isEditing)
                .accessibilityLabel(title)
            if let unit {
                Text(unit)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, alignment: .leading)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isEditing {
                    Spacer()
                    Button("Done") { isEditing = false }
                }
            }
        }
    }
}

/// A binding that clamps whatever is written to it into `range` and ignores non-finite values.
func clamped(_ binding: Binding<Double>, to range: ClosedRange<Double>) -> Binding<Double> {
    Binding(
        get: { binding.wrappedValue },
        set: { newValue in
            guard newValue.isFinite else { return }
            binding.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
        }
    )
}

// MARK: - Progress

/// Animated ring. `progress` can exceed 1; the ring stops at a full circle.
struct ProgressRing<Center: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 16
    var colors: [Color] = [Theme.saffron, Theme.chilli]
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(shown, 0), 1)))
                .stroke(
                    AngularGradient(
                        colors: colors + [colors.last ?? Theme.chilli],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            center()
        }
        .onAppear { update(to: progress, delay: 0.1) }
        .onChange(of: progress) { _, newValue in update(to: newValue, delay: 0) }
    }

    private func update(to newValue: Double, delay: Double) {
        if reduceMotion {
            shown = newValue
        } else {
            withAnimation(.easeOut(duration: 0.9).delay(delay)) { shown = newValue }
        }
    }
}

/// Labelled, colored progress bar for a macro or other target.
struct MacroBar: View {
    let emoji: String
    let name: String
    let value: Double
    let target: Double
    var unit: String = "g"
    var color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    private var fraction: Double { target > 0 ? value / target : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(emoji) \(name)")
                    .font(.rounded(.subheadline, weight: .semibold))
                Spacer()
                Text("\(Int(value.rounded())) / \(Int(target.rounded())) \(unit)")
                    .font(.rounded(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(0, geo.size.width * CGFloat(min(shown, 1))))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue("\(Int(value.rounded())) of \(Int(target.rounded())) \(unit)")
        .onAppear { update(to: fraction) }
        .onChange(of: fraction) { _, newValue in update(to: newValue) }
    }

    private func update(to newValue: Double) {
        if reduceMotion {
            shown = newValue
        } else {
            withAnimation(.easeOut(duration: 0.7)) { shown = newValue }
        }
    }
}

/// Stacked bar showing how calories split between protein, carbs and fat.
struct MacroSplitBar: View {
    let proteinG: Double
    let carbG: Double
    let fatG: Double

    private var kcal: (protein: Double, carbs: Double, fat: Double) {
        (proteinG * 4, carbG * 4, fatG * 9)
    }

    private var total: Double { max(1, kcal.protein + kcal.carbs + kcal.fat) }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let usable = max(0, geo.size.width - 4)
                HStack(spacing: 2) {
                    Theme.protein.frame(width: usable * kcal.protein / total)
                    Theme.carbs.frame(width: usable * kcal.carbs / total)
                    Theme.fat.frame(width: usable * kcal.fat / total)
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())

            HStack {
                legend("🥚", "Protein", kcal.protein, Theme.protein)
                Spacer()
                legend("🍚", "Carbs", kcal.carbs, Theme.carbs)
                Spacer()
                legend("🥑", "Fat", kcal.fat, Theme.fat)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calorie split")
        .accessibilityValue("Protein \(Int((kcal.protein / total * 100).rounded())) percent, carbs \(Int((kcal.carbs / total * 100).rounded())) percent, fat \(Int((kcal.fat / total * 100).rounded())) percent")
    }

    private func legend(_ emoji: String, _ name: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(emoji) \(name) \(Int((value / total * 100).rounded()))%")
                .font(.rounded(.caption, weight: .medium))
        }
    }
}

// MARK: - Misc

struct FriendlyEmptyState: View {
    let emoji: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 64))
                .accessibilityHidden(true)
            Text(title)
                .font(.rounded(.title3, weight: .bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.rounded(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.gradient)
                    .padding(.top, 8)
                    .frame(maxWidth: 260)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

/// Section title with a leading emoji.
struct EmojiHeader: View {
    let emoji: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text("\(emoji) \(title)")
                .font(.rounded(.headline, weight: .bold))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
        .foregroundStyle(.primary)
    }
}
