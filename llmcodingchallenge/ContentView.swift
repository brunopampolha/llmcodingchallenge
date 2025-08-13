//
//  ContentView.swift
//  llmcodingchallenge
//
//  Created by Bruno Pampolha on 11/08/25.
//

import SwiftUI
import Combine

// MARK: - Models (Instruction format)

struct LayoutInstruction: Decodable {
    var background: BackgroundSpec?
    var title: TitleSpec?
    var fields: FieldSpec?
    var button: ButtonSpec?
    var layout: LayoutSpec?
}

struct BackgroundSpec: Decodable {
    var color: String?
}

struct TitleSpec: Decodable {
    var text: String?
    var color: String?
    var fontSize: CGFloat?
}

struct LayoutSpec: Decodable {
    var spacing: CGFloat?
}

struct FieldSpec: Decodable {
    var color: String?
    var textColor: String?
    var cornerRadius: CGFloat?
}

struct ButtonSpec: Decodable {
    var color: String?
    var outline: Bool?
    var fontSize: CGFloat?
    var padding: CGFloat?
    var accentColor: String?
}

// MARK: - Runtime UI State

struct LayoutState {
    var background: Color
    var titleText: String
    var titleColor: Color
    var titleSize: CGFloat
    
    var stackSpacing: CGFloat
    
    var name: String
    var email: String
    
    var nameField: FieldStyle
    var emailField: FieldStyle
    var saveButton: ButtonStyle
    
    static func defaultState() -> LayoutState {
        LayoutState(
            background: Color.from(any: "#1E63C6")!, // blue-ish
            titleText: "My Profile",
            titleColor: .white,
            titleSize: 24,
            stackSpacing: 14,
            name: "",
            email: "",
            nameField: FieldStyle(color: .white, textColor: .black, cornerRadius: 8),
            emailField: FieldStyle(color: .white, textColor: .black, cornerRadius: 8),
            saveButton: ButtonStyle(outline: false, fontSize: 16, padding: 10, accentColor: .white, color: Color.black.opacity(0.2))
        )
    }
}

struct FieldStyle {
    var color: Color
    var textColor: Color
    var cornerRadius: CGFloat
    
    mutating func apply(from spec: FieldSpec) {
        if let c = spec.color { color = Color.from(any: c) ?? color }
        if let tc = spec.textColor { textColor = Color.from(any: tc) ?? textColor }
        if let r = spec.cornerRadius { cornerRadius = r }
    }
}

struct ButtonStyle {
    var outline: Bool
    var fontSize: CGFloat
    var padding: CGFloat
    var accentColor: Color
    var color: Color
    
    mutating func apply(from spec: ButtonSpec) {
        if let o = spec.outline { outline = o }
        if let f = spec.fontSize { fontSize = f }
        if let p = spec.padding { padding = p }
        if let a = spec.accentColor { accentColor = Color.from(any: a) ?? accentColor }
        if let c = spec.color { color = Color.from(any: c) ?? color }
    }
}

// MARK: - ViewModel & Runtime State

final class PlaygroundViewModel: ObservableObject {
    @Published var state = LayoutState.defaultState()
    private let decoder = JSONDecoder()
    private let llm = OpenAIClient(apiKey: Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String)
    
    func reset() {
        state = .defaultState()
    }
    
    func handle(prompt raw: String) {
        let prompt = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }
        
        if prompt.lowercased().hasPrefix("reset") {
            reset(); return
        }

        if let json = MockPrompts.matchingJSON(for: prompt) {
            apply(json: json)
            return
        }
        
        if prompt.first == "{", let data = prompt.data(using: .utf8) {
            if let instr = try? decoder.decode(LayoutInstruction.self, from: data) {
                apply(instruction: instr)
                return
            }
        }
        
        guard let llm = llm else { return } // no key set
        llm.layoutInstruction(for: prompt) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let contentJSON):
                    self?.apply(json: contentJSON)
                case .failure:
                    break
                }
            }
        }
    }
    
    private func apply(json: String) {
        guard let data = json.data(using: .utf8),
              let instr = try? decoder.decode(LayoutInstruction.self, from: data)
        else { return }
        apply(instruction: instr)
    }
    
    private func apply(instruction: LayoutInstruction) {
        // Background
        if let bg = instruction.background?.color {
            state.background = Color.from(any: bg) ?? state.background
        }
        // Title
        if let title = instruction.title {
            if let t = title.text { state.titleText = t }
            if let c = title.color { state.titleColor = Color.from(any: c) ?? state.titleColor }
            if let s = title.fontSize { state.titleSize = s }
        }
        // Fields
        if let fields = instruction.fields {
            state.nameField.apply(from: fields)
            state.emailField.apply(from: fields)
        }
        // Button
        if let button = instruction.button {
            state.saveButton.apply(from: button)
        }
        // Layout
        if let layout = instruction.layout {
            if let sp = layout.spacing { state.stackSpacing = sp }
        }
    }
}

// MARK: - View

struct ContentView: View {
    @StateObject private var vm = PlaygroundViewModel()
    @State private var prompt: String = ""
    
    var body: some View {
        ZStack {
            vm.state.background
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                header
                
                Spacer(minLength: 16)
                
                VStack(alignment: .center, spacing: vm.state.stackSpacing) {
                    Group {
                        nameField
                        emailField
                    }
                    
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                inputBar
            }
        }
    }
    
    // MARK: Pieces
    
    private var header: some View {
        Text(vm.state.titleText)
            .font(.system(size: vm.state.titleSize, weight: .semibold))
            .foregroundColor(vm.state.titleColor)
            .padding(.top, 24)
    }
    
    private var nameField: some View {
        StyledTextField("Name", text: $vm.state.name, style: vm.state.nameField)
    }
    
    private var emailField: some View {
        StyledTextField("Email", text: $vm.state.email, style: vm.state.emailField)
            .keyboardType(.emailAddress)
    }
    
    private var saveButton: some View {
        Button(action: {}) {
            Text("[ Save ]")
                .font(.system(size: vm.state.saveButton.fontSize, weight: .semibold))
                .foregroundColor(vm.state.saveButton.accentColor)
                .padding(.vertical, vm.state.saveButton.padding)
                .frame(maxWidth: .infinity)
                .background(
                    vm.state.saveButton.outline ?
                        AnyView(RoundedRectangle(cornerRadius: 12).stroke(vm.state.saveButton.accentColor, lineWidth: 2))
                        : AnyView(RoundedRectangle(cornerRadius: 12).fill(vm.state.saveButton.color))
                )
        }
        .padding(.top, 4)
    }
    
    private var inputBar: some View {
        VStack(alignment: .center, spacing: vm.state.stackSpacing) {
            Divider().background(Color.black.opacity(0.15))
            TextField("Try: make the background green", text: $prompt, onCommit: sendPrompt)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(10)
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
            
            HStack {
                Button(action: sendPrompt) {
                    Text("Send")
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.black.opacity(0.1)).cornerRadius(10)
                        .foregroundColor(.white)
                }
                Button(action: { vm.reset() }) {
                    Text("Reset")
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.black.opacity(0.06)).cornerRadius(10)
                        .foregroundColor(.white)
                }
            }
            // Quick examples row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MockPrompts.examples, id: \.self) { ex in
                        Button(ex) { prompt = ex; sendPrompt() }
                            .font(.system(size: 12))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white.opacity(0.85))
                            .cornerRadius(8)
                    }
                }.padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(Color.white.opacity(0.15))
    }
    
    private func sendPrompt() {
        let p = prompt
        prompt = ""
        vm.handle(prompt: p)
    }
}

// MARK: - Styled TextField

struct StyledTextField: View {
    var placeholder: String
    @Binding var text: String
    var style: FieldStyle
    
    init(_ placeholder: String, text: Binding<String>, style: FieldStyle) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text("\(placeholder):")
                    .foregroundColor(style.textColor.opacity(0.7))
                    .padding(.leading, 12)
            }
            TextField("", text: $text)
                .foregroundColor(style.textColor)
                .padding(10)
        }
        .background(style.color)
        .cornerRadius(style.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Mocked Prompts → JSON

enum MockPrompts {
    // Shown as quick actions
    static let examples: [String] = [
        "make the background green",
        "make inputs light pink",
        "increase spacing",
        "make the save button outlined and bigger"
    ]
    
    static func matchingJSON(for promptRaw: String) -> String? {
        let p = promptRaw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch p {
        case "make the background green", "background green", "green background":
            // Change background & keep the same title
            return """
            {
              "background": { "color": "#10B981" },
              "title": { "color": "#FFFFFF" }
            }
            """
        case "make inputs light pink", "inputs light pink":
            return """
            { "fields": { "color": "#FFB6C1" } }
            """
        case "increase spacing", "bigger spacing", "make space bigger":
            return """
            { "layout": { "spacing": 32 } }
            """
        case "make the save button outlined and bigger", "big outlined save":
            return """
            { "button": { "outline": true, "fontSize": 18, "padding": 12, "accentColor": "#064E3B", "fontSize": 26 } }
            """
        default:
            return nil
        }
    }
}

// MARK: - Color helpers (iOS 14 friendly)

extension Color {
    static func from(any string: String) -> Color? {
        if let ui = UIColor.from(any: string) { return Color(ui) }
        return nil
    }
}

extension UIColor {
    static func from(any string: String) -> UIColor? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { return UIColor(hex: s) }
        switch s.lowercased() {
        case "white": return .white
        case "black": return .black
        case "red": return .systemRed
        case "green": return .systemGreen
        case "blue": return .systemBlue
        case "gray", "grey": return .systemGray
        default: return UIColor(hex: s)
        }
    }
    
    convenience init?(hex: String) {
        var hexString = hex
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        guard hexString.count == 6,
              let rgb = Int(hexString, radix: 16) else { return nil }
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
