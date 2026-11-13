# TypeSpeed

Тест скорости печати для macOS (нативное окно на Swift + WKWebView).

## Сборка

    bash build.sh            # собрать и запустить build/TypeSpeed.app
    bash build.sh install    # собрать и положить в /Applications

Нужны Command Line Tools (`xcode-select --install`), Xcode не обязателен.

## Структура

- `Sources/main.swift` - окно, меню, синхронизация цвета заголовка с темой
- `Resources/index.html` - весь интерфейс и логика теста (можно открыть и в браузере)
- `Resources/AppIcon.icns` - иконка
