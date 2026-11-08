import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView(selection: $model.tab) {
            GeneralTab(model: model)
                .tabItem { Label("Chung", systemImage: "gearshape") }
                .tag("general")
            TypingTab(model: model)
                .tabItem { Label("Gõ", systemImage: "keyboard") }
                .tag("typing")
            MacrosTab(model: model)
                .tabItem { Label("Gõ tắt", systemImage: "text.badge.plus") }
                .tag("macros")
            AppsTab(model: model)
                .tabItem { Label("Ứng dụng", systemImage: "square.grid.2x2") }
                .tag("apps")
            AboutTab()
                .tabItem { Label("Giới thiệu", systemImage: "info.circle") }
                .tag("about")
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 440)
    }
}

struct GeneralTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Picker("Kiểu gõ", selection: $model.prefs.method) {
                Text("Telex").tag("telex")
                Text("VNI").tag("vni")
                Text("Simple Telex").tag("simple_telex")
            }
            Picker("Đặt dấu", selection: $model.prefs.toneStyle) {
                Text("Kiểu mới — hoà, khoẻ, thuỷ").tag("new")
                Text("Kiểu cũ — hòa, khỏe, thủy").tag("old")
            }
            Picker("Phím chuyển Việt/Anh", selection: $model.prefs.toggleShortcut) {
                ForEach(ToggleShortcut.allCases) { Text($0.label).tag($0) }
            }
            Text("Nhấn rồi nhả tổ hợp phím, không kèm phím khác.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Nhớ Việt/Anh theo từng ứng dụng", isOn: $model.prefs.rememberPerApp)
            Toggle("Hiện V/E trên thanh menu", isOn: $model.prefs.showStatusItem)
        }
        .formStyle(.grouped)
    }
}

struct TypingTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle("Gạch chân chữ đang gõ", isOn: Binding(
                    get: { !model.prefs.directTyping },
                    set: { model.prefs.directTyping = !$0 }))
                Text("Bỏ dấu tích để gõ thẳng vào văn bản, không gạch chân. Gõ thẳng chỉ dùng cho ứng dụng "
                     + "đã được kiểm chứng đọc lại đúng (sau hai từ đầu); ứng dụng khác tự dùng gạch chân an toàn.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Kiểm tra âm tiết (chỉ bỏ dấu cho âm tiết hợp lệ)", isOn: $model.prefs.spellCheck)
                Toggle("Tự khôi phục từ tiếng Anh (text, with, user…)", isOn: $model.prefs.autoRestore)
            }
            Section("Telex") {
                Toggle("w đứng riêng thành ư", isOn: $model.prefs.wAsU)
                Toggle("[ thành ơ, ] thành ư", isOn: $model.prefs.brackets)
            }
        }
        .formStyle(.grouped)
    }
}

struct MacrosTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Bật gõ tắt", isOn: $model.prefs.macrosEnabled)
            Text("Bung khi kết thúc từ. Giữ kiểu hoa: vn → Việt Nam, VN → VIỆT NAM.")
                .font(.caption).foregroundStyle(.secondary)
            Table($model.prefs.macros, selection: $model.macroSelection) {
                TableColumn("Từ tắt") { $m in
                    TextField("vd: vn", text: $m.key)
                }
                .width(min: 80, ideal: 120, max: 200)
                TableColumn("Thay bằng") { $m in
                    TextField("vd: Việt Nam", text: $m.value)
                }
            }
            HStack {
                Button { model.addMacro() } label: { Image(systemName: "plus") }
                Button { model.removeSelectedMacros() } label: {
                    Image(systemName: "minus")
                }
                .disabled(model.macroSelection.isEmpty)
                Spacer()
                Button("Nhập JSON…") { model.importMacros() }
                Button("Xuất JSON…") { model.exportMacros() }
            }
            if let msg = model.message {
                Text(msg).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct AppsTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Luôn gõ tiếng Anh") {
                AppList(ids: $model.prefs.alwaysEnglishApps)
                Button("Thêm ứng dụng…") { model.addAlwaysEnglish() }
            }
            Section("Luôn gõ tiếng Việt") {
                AppList(ids: $model.prefs.alwaysVietnameseApps)
                Button("Thêm ứng dụng…") { model.addAlwaysVietnamese() }
            }
            Section("Đã nhớ theo ứng dụng") {
                if model.appModes.isEmpty {
                    Text("Chưa có").foregroundStyle(.secondary)
                } else {
                    ForEach(model.appModes.keys.sorted(), id: \.self) { id in
                        HStack {
                            Text(SettingsModel.appName(id))
                            Spacer()
                            Text(model.appModes[id] == true ? "V" : "E").monospaced()
                        }
                    }
                    Button("Quên tất cả") { model.clearRemembered() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AppList: View {
    @Binding var ids: [String]

    var body: some View {
        if ids.isEmpty {
            Text("Chưa có").foregroundStyle(.secondary)
        }
        ForEach(ids, id: \.self) { id in
            HStack {
                VStack(alignment: .leading) {
                    Text(SettingsModel.appName(id))
                    Text(id).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) { ids.removeAll { $0 == id } } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Phím Việt").font(.largeTitle.bold())
            Text("Phiên bản \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                .foregroundStyle(.secondary)
            Text("Bộ gõ tiếng Việt cho macOS dùng InputMethodKit — không cần quyền Trợ năng, "
                 + "không gửi phím giả.")
                .multilineTextAlignment(.center)
            Text("Riêng tư: không kết nối mạng, không thu thập dữ liệu, không ghi nội dung bạn gõ.")
                .multilineTextAlignment(.center).font(.callout).foregroundStyle(.secondary)
            Text("Giấy phép MIT").font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
