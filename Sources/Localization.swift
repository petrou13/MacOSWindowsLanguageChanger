import Foundation

func L(_ key: String) -> String { WSLocalized(key) }
func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: Locale(identifier: WSInterfaceLanguage()), arguments: arguments)
}
