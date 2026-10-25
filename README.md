<div align="center">

<img src="assets/banner.png" alt="Liji" width="100%"/>

# Liji

**Операционная система на базе Zircon и Fuchsia с десктоп-окружением Mejo**

[![License](https://img.shields.io/badge/license-Apache--2.0-D0BCFF?style=flat-square)](LICENSE)
[![CI](https://img.shields.io/badge/CI-GitHub_Actions-7D5260?style=flat-square)](.github/workflows/ci.yml)
[![База](https://img.shields.io/badge/база-Fuchsia_\/_Zircon-CCC2DC?style=flat-square)](docs/architecture.md)

</div>

---

## Что это

Liji — экспериментальная десктопная ОС. Ядро — Zircon, системная база — урезанное ядро Fuchsia, оболочка — Mejo. Из платформы берётся только то, что делает её настоящей ОС: компонентный фреймворк, драйверы, графика, ввод, звук, сеть, обновления. Никаких сэмплов, демо и мёртвых перталсов.

Урезание ведётся штатными механизмами платформы, а не удалением каталогов: лёгкий манифест jiri (`stem` вместо `flower`) на этапе выкачки и продуктовая конфигурация `fx set` с собственным файлом продукта на этапе сборки. Liji собирается из чистого чекаута стандартными инструментами Fuchsia, и любой другой сборщик может использовать то же дерево исходников для своего продукта без сюрпризов.

## Ключевые решения

| Компонент | Выбор | Почему |
|---|---|---|
| Ядро | Zircon | Микроядро, capability-безопасность, драйверы в user space |
| Системная база | Fuchsia core | CFv2, FIDL, Scenic, netstack, файловые системы |
| Оболочка | Mejo | Единый рендер и единая дизайн-система на весь UI |
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
├── scripts/           выкачка исходников Fuchsia
└── .github/           CI: выкачка в Actions, проверки
```

## Выкачка и сборка

Локально (порядка 7 ГБ под исходники, 80–90 ГБ под сборку):

```bash
./scripts/fetch_fuchsia.sh
```

В GitHub Actions: вкладка Actions → **fetch** → Run workflow. Чекаут jiri кэшируется между запусками, объём и состав пишутся в Summary джобы.

Сборка и запуск в QEMU/FEMU — по шагам в [docs/build.md](docs/build.md).

## Дорожная карта

- **Фаза 1** — выкачка, первая сборка `core.x64`, запуск в FEMU *(выкачка уже работает в CI)*
- **Фаза 2** — минимальный образ Liji: загрузка, вход, системные сервисы
- **Фаза 3** — Flutter runtime в образе, первый нативный UI-компонент
- **Фаза 4** — Mejo MVP: shell, лаунчер, окна

Детали — в [docs/roadmap.md](docs/roadmap.md).

## English summary

Liji is an experimental desktop OS: the Zircon microkernel, a trimmed Fuchsia core as the system base, and the Mejo desktop shell. Trimming is done with the platform's own mechanisms — the `stem` jiri manifest for checkout and `fx set` product configurations for builds — so Liji builds from a clean checkout with standard Fuchsia tooling. Fetch sources with `scripts/fetch_fuchsia.sh` or the CI `fetch` workflow; build steps are in [docs/build.md](docs/build.md).

## Юридическая заметка

Проект не аффилирован с Google. Fuchsia, Zircon и Material — торговые марки Google LLC; используются открытые исходники Fuchsia в соответствии с его лицензиями (BSD, MIT, Apache-2.0). Код Liji — [Apache-2.0](LICENSE).
