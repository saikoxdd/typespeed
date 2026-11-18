# TypeSpeed

Тест скорости печати для macOS (нативное окно на Swift + WKWebView).

![TypeSpeed](docs/screenshot.png)

A minimal Monkeytype-style typing test packed into a native macOS app: a Swift window around a single-page UI.

- режимы «время» (15 / 30 / 60 / 120 с) и «слова», знаки препинания и цифры по желанию
- русский и английский, словари на 200 / 1k / 2k самых частых слов
- профиль со статистикой всех тестов, несколько цветовых тем
- `tab` / `esc` - заново, `⌥ + ⌫` - стереть слово

## Сборка

    bash build.sh            # собрать и запустить build/TypeSpeed.app
    bash build.sh install    # собрать и положить в /Applications

Нужны Command Line Tools (`xcode-select --install`), Xcode не обязателен.

## Структура

- `Sources/main.swift` - окно, меню, синхронизация цвета заголовка с темой
- `Resources/index.html` - весь интерфейс и логика теста (можно открыть и в браузере)
- `Resources/AppIcon.icns` - иконка
