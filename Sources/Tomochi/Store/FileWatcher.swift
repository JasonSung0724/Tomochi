import Foundation

/// Watches a directory (non-recursively) for writes using a
/// DispatchSource file-system object source, with debounce.
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fd: CInt = -1
    private var debounceWorkItem: DispatchWorkItem?
    private let url: URL
    private let onChange: () -> Void

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    private func start() {
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.debounceWorkItem?.cancel()
            let item = DispatchWorkItem { self.onChange() }
            self.debounceWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }
        source.setCancelHandler { [fd = self.fd] in
            if fd >= 0 { close(fd) }
        }
        source.resume()
        self.source = source
    }

    deinit {
        source?.cancel()
    }
}
