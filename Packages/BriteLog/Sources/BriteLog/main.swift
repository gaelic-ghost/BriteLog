import BriteLogCLI

@available(macOS 10.15, *)
@main
enum BriteLogExecutable {
    static func main() {
        runBriteLogCLI()
    }
}
