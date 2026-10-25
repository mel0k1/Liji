# Mejo

Оболочка (DE) Liji. Текущий каркас: системная панель с часами и кнопкой лаунчера, сетка приложений, welcome-экран. Дизайн-система — Material 3 Expressive (`useMaterial3`).

## Локальный запуск

```bash
flutter pub get
flutter run
```

## Интеграция с Fuchsia

`meta/mejo_shell.cml` описывает компонент под `flutter_jit_product_runner`. Сборка `.far` и подключение к продукту `products/liji.gi` выполняются против выкачки Fuchsia — см. [docs/build.md](../docs/build.md).

## Модули

- `mejo_shell` — корневой компонент сессии (этот каркас)
- `mejo_launcher` — лаунчер приложений
- `mejo_panel` — системная панель
- `mejo_wm` — компоновка окон
- `mejo_kit` — дизайн-система
