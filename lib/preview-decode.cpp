#include <QBuffer>
#include <QCoreApplication>
#include <QFile>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QTextStream>
#include <QtEndian>
#include <cstring>
#include <new>

namespace {
int fail(const QString &message) {
    QTextStream(stderr) << "Preview decoder: " << message << '\n';
    return 1;
}

bool hasCodecs() {
    return QImageReader::supportedImageFormats().contains("webp")
        && QImageWriter::supportedImageFormats().contains("png");
}

int decode(const QString &inputPath, const QString &outputPath, bool originalSize) {
    QFile input(inputPath);
    if (!input.open(QIODevice::ReadOnly))
        return fail("cannot open input");
    if (input.size() <= 0 || input.size() > 8 * 1024 * 1024)
        return fail("input exceeds the 8 MiB limit or is empty");

    // Qt 6.11's WebP handler incorrectly requires sizeof(WebPBitstreamFeatures)
    // header bytes even for complete, valid lossless WebPs shorter than 40 bytes.
    // Pad only outside a complete RIFF container; never repair truncated input.
    QByteArray tinyBytes;
    QBuffer tinyInput(&tinyBytes);
    QIODevice *device = &input;
    if (input.size() < 64) {
        tinyBytes = input.readAll();
        if (tinyBytes.size() < 12 || !tinyBytes.startsWith("RIFF")
            || tinyBytes.mid(8, 4) != "WEBP"
            || qFromLittleEndian<quint32>(tinyBytes.constData() + 4)
                != static_cast<quint32>(tinyBytes.size() - 8))
            return fail("invalid or truncated WebP container");
        tinyBytes.resize(64, '\0');
        tinyInput.open(QIODevice::ReadOnly);
        device = &tinyInput;
    }
    QImageReader::setAllocationLimit(64);
    QImageReader reader(device, "webp");
    reader.setAutoDetectImageFormat(false);
    reader.setDecideFormatFromContent(false);
    reader.setAutoTransform(false);
    if (!reader.canRead())
        return fail("input is not a readable WebP image");
    const QSize original = reader.size();
    if (!original.isValid() || original.width() > 8192 || original.height() > 8192)
        return fail("invalid image dimensions or dimensions exceed 8192 pixels");
    QSize target = original;
    if (!originalSize && (target.width() > 1200 || target.height() > 1200)) {
        const double ratio = 1200.0 / qMax(target.width(), target.height());
        target = QSize(qRound(target.width() * ratio), qRound(target.height() * ratio));
    }
    target.setWidth(qMax(1, target.width()));
    target.setHeight(qMax(1, target.height()));
    reader.setScaledSize(target);
    // One read decodes only the first frame of an animated WebP.
    QImage decoded = reader.read();
    if (decoded.isNull())
        return fail("WebP decoding failed: " + reader.errorString());
    if (decoded.width() > 8192 || decoded.height() > 8192)
        return fail("decoded dimensions exceed 8192 pixels");
    if (decoded.size() != target)
        decoded = decoded.scaled(target, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    decoded = decoded.convertToFormat(QImage::Format_ARGB32);
    if (decoded.isNull())
        return fail("cannot allocate decoded image");

    // Copy pixels into a fresh image so profiles, text and other source metadata
    // cannot propagate into the cached PNG.
    QImage clean(decoded.size(), QImage::Format_ARGB32);
    if (clean.isNull())
        return fail("cannot allocate output image");
    for (int row = 0; row < decoded.height(); ++row)
        std::memcpy(clean.scanLine(row), decoded.constScanLine(row),
                    static_cast<size_t>(decoded.width()) * 4);
    QImageWriter writer(outputPath, "png");
    if (!writer.write(clean))
        return fail("PNG encoding failed: " + writer.errorString());
    return 0;
}
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    const QStringList args = app.arguments();
    const bool check = args.size() == 2 && args.at(1) == "--check";
    const bool originalSize = args.size() == 4 && args.at(3) == "--original";
    if (!check && args.size() != 3 && !originalSize)
        return fail("usage: preview-decode INPUT.webp OUTPUT.png [--original] | --check");
    if (!hasCodecs())
        return fail("WebP/PNG support is missing; install qt6-imageformats and qt6-base");
    if (check)
        return 0;
    try {
        return decode(args.at(1), args.at(2), originalSize);
    } catch (const std::bad_alloc &) {
        return fail("image allocation exceeded available memory");
    }
}
