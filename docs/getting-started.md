# Getting Started (С Нуля)

Пошаговая инструкция для нового ПК: как скачать репозитории, создать папки, запустить окружение и проверить, что CRM работает.

Стек проекта: `PHP 7.0 + Debian Stretch + MySQL 5.7` (legacy).

## 1) Что должно быть установлено

Проверьте инструменты:

```bash
git --version
docker --version
docker compose version
make --version
```

Если какой-то команды нет, установите ее в системе и повторите проверку.

## 2) Скачайте infra-репозиторий

Создайте рабочую папку и клонируйте проект:

```bash
mkdir -p ~/projects
cd ~/projects
git clone <INFRA_REPO_URL> MBE
cd MBE
```

## 3) Подготовьте папки с кодом CRM

По умолчанию инфраструктура ожидает код CRM в `./html/mbelab.com/crm`.

```bash
mkdir -p html/mbelab.com
git clone <PRIVATE_CRM_REPO_URL> html/mbelab.com/crm
```

Если хотите хранить CRM-код в другом месте, задайте `APP_CODE_PATH` в `.env`.

## 4) Создайте локальный `.env`

```bash
cp env.example .env
```

Проверьте минимум:

- `APP_CODE_PATH` указывает на папку, где лежит `crm`
- `CRM_CONFIG_PATH=./configs/crm` (обычно оставляем как есть)
- параметры MySQL заполнены

## 5) Первый запуск

```bash
make up-build
make ps
```

> **ВАЖНО:** <u>без импорта рабочего дампа базы данных CRM не будет нормально работать.</u>  
> После первого запуска контейнеров обязательно импортируйте дамп, иначе система будет в "пустом" состоянии с некорректными данными/процессами.
>
> ```bash
> make db-import FILE=dump/<YOUR_FILE>.sql.gz
> ```

Проверка:

- CRM: `http://localhost:8081`
- MySQL: `127.0.0.1:33063`

Логи:

```bash
make logs
```

Остановить окружение:

```bash
make down
```

## 6) Ежедневная работа

Обычно достаточно:

```bash
make up
make ps
```

Если менялся `Dockerfile` или build context:

```bash
make up-build
```

Если нужен полностью чистый rebuild образов:

```bash
make rebuild
make up
```

## 7) Базовые команды CRM

```bash
make tracking
make vtiger-cron
```

## 8) Бэкап и импорт БД

Создать дамп:

```bash
make db-dump
```

Импорт:

```bash
make db-import FILE=dump/<YOUR_FILE>.sql.gz
```

## 9) Deploy (опционально)

Создать deploy-конфиг:

```bash
cp .env.deploy.example .env.deploy
```

Проверка без изменений:

```bash
make deploy-dry
```

Реальный деплой:

```bash
make deploy
```

## 10) Если что-то не работает

1. Проверить статусы: `make ps`
2. Посмотреть логи: `make logs` и `make logs SERVICE=mysql`
3. Проверить переменные в `.env` (`APP_CODE_PATH`, MySQL параметры)
4. Проверить, что директория `APP_CODE_PATH` содержит `crm`
