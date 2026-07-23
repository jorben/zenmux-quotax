import AppKit
import SwiftUI

func settingsCard<Content: View>(
    icon: String,
    title: String,
    subtitle: String,
    @ViewBuilder content: () -> Content
) -> some View {
    settingsCard(icon: icon, title: title, subtitle: subtitle, headerAction: { EmptyView() }, content: content)
}

func settingsCard<Content: View, HeaderAction: View>(
    icon: String,
    title: String,
    subtitle: String,
    @ViewBuilder headerAction: () -> HeaderAction,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            headerAction()
        }

        content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
    .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
}
