// Test-only fixture generator/inspector; uses the same installed Qt image plugins.
#include <QBuffer>
#include <QCoreApplication>
#include <QFile>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QTextStream>
#include <webp/mux.h>
#include <cstdlib>

static void require(bool condition, const char *message) {
    if (!condition) { QTextStream(stderr) << message << '\n'; std::exit(1); }
}

static QByteArray encoded(int width, int height, const QColor &color, const char *format) {
    QImage image(width, height, QImage::Format_ARGB32);
    require(!image.isNull(), "Cannot allocate fixture image");
    image.fill(color);
    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    QImageWriter writer(&buffer, format);
    writer.setQuality(100);
    require(writer.write(image), "Cannot encode fixture; install qt6-imageformats for WebP support");
    return bytes;
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    const auto args = app.arguments();
    require(args.size() >= 3, "Usage: fixture inspect FILE | make FILE WIDTH HEIGHT [png|metadata|animation]");
    if (args[1] == "inspect") {
        QImageReader reader(args[2]);
        const QByteArray format = reader.format();
        const QImage image = reader.read();
        require(!image.isNull(), "Cannot read fixture output");
        QTextStream(stdout) << format.toUpper() << ' ' << image.width() << 'x' << image.height()
                            << ' ' << image.pixelColor(0, 0).name() << ' ' << image.pixelColor(0, 0).alpha() << '\n';
        require(image.textKeys().isEmpty(), "Output contains text metadata");
        return 0;
    }
    require(args[1] == "make" && args.size() >= 5, "Invalid fixture arguments");
    const QString mode = args.value(5);
    QColor color("#285e81");
    if (mode == "alpha") color.setAlpha(128);
    QByteArray bytes = encoded(args[3].toInt(), args[4].toInt(), color, mode == "png" ? "png" : "webp");
    if (mode == "metadata" || mode == "animation") {
        WebPMux *mux = WebPMuxNew();
        require(mux != nullptr, "Cannot create WebP mux");
        const WebPData data{reinterpret_cast<const uint8_t *>(bytes.constData()), size_t(bytes.size())};
        if (mode == "animation") {
            const WebPMuxAnimParams params{0, 0};
            require(WebPMuxSetAnimationParams(mux, &params) == WEBP_MUX_OK, "Cannot set animation params");
            WebPMuxFrameInfo frame{};
            frame.bitstream = data;
            frame.duration = 100;
            frame.id = WEBP_CHUNK_ANMF;
            frame.blend_method = WEBP_MUX_NO_BLEND;
            require(WebPMuxPushFrame(mux, &frame, 1) == WEBP_MUX_OK, "Cannot add first animation frame");
            const QByteArray second = encoded(args[3].toInt(), args[4].toInt(), Qt::red, "webp");
            frame.bitstream = {reinterpret_cast<const uint8_t *>(second.constData()), size_t(second.size())};
            require(WebPMuxPushFrame(mux, &frame, 1) == WEBP_MUX_OK, "Cannot add second animation frame");
        } else {
            require(WebPMuxSetImage(mux, &data, 1) == WEBP_MUX_OK, "Cannot set metadata image");
            const QByteArray metadata("<x:xmpmeta xmlns:x='adobe:ns:meta/'>private-preview-test-metadata</x:xmpmeta>");
            const WebPData xmp{reinterpret_cast<const uint8_t *>(metadata.constData()), size_t(metadata.size())};
            require(WebPMuxSetChunk(mux, "XMP ", &xmp, 1) == WEBP_MUX_OK, "Cannot add metadata");
        }
        WebPData output{};
        require(WebPMuxAssemble(mux, &output) == WEBP_MUX_OK, "Cannot assemble fixture");
        bytes = QByteArray(reinterpret_cast<const char *>(output.bytes), qsizetype(output.size));
        WebPDataClear(&output);
        WebPMuxDelete(mux);
    }
    QFile file(args[2]);
    require(file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size(), "Cannot write fixture");
}
