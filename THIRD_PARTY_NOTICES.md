# Third-party notices

Voxly is built on the open-source software and models below. Their full license
texts ship with the app in `Voxly.app/Contents/Resources/Litsenziyalar.txt`
(Settings → «Лицензии…» / «Licenses…»). The file is generated at build time by
`scripts/litsenziyalar.sh` from the LICENSE files of the pinned sources.

## macOS app

### Models

| Model | License | Used for | Notes |
|---|---|---|---|
| [OpenAI Whisper large-v3-turbo](https://github.com/openai/whisper) ([ggml build](https://huggingface.co/ggerganov/whisper.cpp)) | MIT | Russian and English speech recognition | Downloaded on first launch, q5_0 quantization, ~550 MB |
| [rubaiSTT v2 medium](https://huggingface.co/islomov/rubaistt_v2_medium) by **islomov** | Apache-2.0 | Uzbek speech recognition (optional) | Attribution required. Converted to ggml, q8_0 |
| [OpenAI Whisper medium](https://github.com/openai/whisper) | MIT | Base model that rubaiSTT is fine-tuned from | |
| [Silero VAD v6.2.0](https://github.com/snakers4/silero-vad) by Silero Team ([ggml build](https://huggingface.co/ggml-org/whisper-vad)) | MIT | Speech detection and splitting long audio | Bundled with the app, 885 KB |

### Software

| Component | License | Used for |
|---|---|---|
| [whisper.cpp / ggml](https://github.com/ggml-org/whisper.cpp) | MIT | Speech recognition engine, statically linked |
| Apple Accelerate, AVFoundation, AppKit | Apple SDK | System frameworks, not redistributed |

The offline translator from the original project (NLLB-200, CC-BY-NC-4.0,
non-commercial only) was **removed** from Voxly together with its engine
(CTranslate2, SentencePiece).

## Windows port (`win/`)

The Windows port (`win/`, work in progress) has the same feature set minus the
translator, auto-updater and statistics. In addition to whisper.cpp it ships
LLVM libc++/libunwind/OpenMP (Apache-2.0 WITH LLVM-exception), the mingw-w64
runtime (ZPL-2.1) and is packaged with Inno Setup. Its full license file is
built with `scripts/litsenziyalar.sh <file> win`.

## Voxly itself

Voxly is a fork of [Kotib](https://github.com/MuhammadMirrr/kotib) by
Muhammad Mirqobilov, released under the [MIT License](LICENSE). The MIT license
allows commercial use and modification. The original copyright notice must stay
in `LICENSE` and in every copy of the app.
