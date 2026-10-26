<div align="center">

<img src="assets/banner.png" alt="Liji" width="100%"/>

# Liji

**Операционная система на базе Zircon и Fuchsia с десктоп-окружением Mejo**

[![License](https://img.shields.io/badge/license-Apache--2.0-D0BCFF?style=flat-square)](LICENSE)
[![CI](https://github.com/mel0k1/Liji/actions/workflows/ci.yml/badge.svg)](https://github.com/mel0k1/Liji/actions/workflows/ci.yml)
[![source-snapshot](https://github.com/mel0k1/Liji/actions/workflows/source-snapshot.yml/badge.svg)](https://github.com/mel0k1/Liji/actions/workflows/source-snapshot.yml)
[![build](https://github.com/mel0k1/Liji/actions/workflows/build.yml/badge.svg)](https://github.com/mel0k1/Liji/actions/workflows/build.yml)
[![База](https://img.shields.io/badge/база-Fuchsia_\/_Zircon-CCC2DC?style=flat-square)](docs/architecture.md)

</div>

---

## Что это

Liji — экспериментальная десктопная ОС. В основе — микроядро Zircon. Всё остальное собираем по потребности: своё пишем сами (оболочка Mejo, системные сервисы), а из Fuchsia берём только нужные куски — компонентный фреймворк, драйверы, графику, ввод, звук, сеть, обновления. Лишнее в образ не попадает.

«Брать по нужному» — это не копирование каталогов, а декларативный состав: пул исходников Fuchsia живёт в CI (снапшот по официальному манифесту `stem`), а в образ входит ровно то, что заявлено продуктовым файлом `fx set`. Хочешь убрать подсистему — правишь продукт, а не выкачку. Локально нужен только этот репозиторий: ни 30 ГБ исходников, ни 90 ГБ сборки.

## Ключевые решения

| Компонент | Выбор | Почему |
|---|---|---|
| Ядро | Zircon | Микроядро, capability-безопасность, драйверы в user space |
| Своё | Mejo + сервисы Liji | Пишем сами как компоненты Fuchsia |
| Из Fuchsia | по потребности | CFv2, FIDL, Scenic, netstack, файловые системы — состав задаёт продукт |
| Платформы | x64 → ARM64 | QEMU, затем реальное железо |

## Почему Zircon

- **Изоляция по умолчанию.** Процесс получает только явно выданные права (capability); приложения и сервисы не видят ничего лишнего.
- **Драйверы в user space.** Упавший драйвер перезапускается и не роняет систему.
- **A/B-обновления.** Система обновляется целиком, одним образом, с откатом при неудаче.

Подробности слоёв и сборки — в [docs/architecture.md](docs/architecture.md).

## Структура

```
Liji/
├── assets/            графика
├── docs/              архитектура, roadmap, гайд сборки
├── products/          продуктовая конфигурация Liji (fx set)
├── mejo/              каркас оболочки: панель, часы, лаунчер
├── scripts/           выкачка исходников Fuchsia, boot-тест эмулятора
└── .github/           CI: снапшот исходников, сборка с boot-тестом, проверки
```

## Выкачка и сборка — в CI, без 100 ГБ на диске

Тяжёлое живёт в GitHub Actions, локально нужен только этот репозиторий:

1. **source-snapshot** — выкачка через jiri по официальному манифесту `stem`, упаковка в tar.zst и публикация в Releases (частями по 1.9 ГБ).
2. **build** — восстановление снапшота, `fx set` / `fx build` штатными инструментами и головной boot-тест в FEMU; serial-лог — в артефактах.

Запуск: Actions → соответствующий workflow → Run workflow; сборка стартует и автоматически после свежего снапшота.

Локальная сборка на машине со 100+ ГБ и детали — в [docs/build.md](docs/build.md).

## Дорожная карта

- **Фаза 1** — выкачка, первая сборка и запуск в FEMU *(выкачка и сборка идут в CI)*
- **Фаза 2** — минимальный образ Liji: загрузка, вход, системные сервисы
- **Фаза 3** — Flutter runtime в образе, первый нативный UI-компонент
- **Фаза 4** — Mejo MVP: shell, лаунчер, окна

Детали — в [docs/roadmap.md](docs/roadmap.md).

## English summary

Liji is an experimental desktop OS built on the Zircon microkernel. Everything else is composed on demand: our own parts (the Mejo shell, Liji services) are written from scratch, while selected pieces of Fuchsia (component framework, drivers, graphics, input, audio, networking, updates) are included only when the product asks for them. The Fuchsia source pool lives in CI (a snapshot synced via the official `stem` jiri manifest), and the image contains exactly what the `fx set` product file declares. Source sync and builds run in GitHub CI (`source-snapshot` and `build` workflows), so no huge disk is needed locally; local steps are described in [docs/build.md](docs/build.md).

## Юридическая заметка

Проект не аффилирован с Google. Fuchsia, Zircon и Material — торговые марки Google LLC; используются открытые исходники Fuchsia в соответствии с его лицензиями (BSD, MIT, Apache-2.0). Код Liji — [Apache-2.0](LICENSE).
