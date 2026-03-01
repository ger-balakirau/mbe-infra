# Git Workflow (Infra Repo)

Репозиторий уже существует, поэтому базовый путь: `clone -> pull -> commit -> push`.

Полная установка с нуля (включая `git clone`) описана в `docs/getting-started.md`.

## Клонирование

```bash
mkdir -p ~/projects
cd ~/projects
git clone <INFRA_REPO_URL> mbelab
cd mbelab
```

## Перед началом работы

```bash
git pull --ff-only
git status --short
```

## Проверка перед коммитом

```bash
make help >/dev/null
git status --short
```

## Коммит и пуш

```bash
git add -A
git commit -m "docs: update instructions"
git push
```

## Полезно

- `git diff` — посмотреть изменения до `git add`
- `git restore --staged <file>` — убрать файл из staged
- `git log --oneline -20` — последние 20 коммитов
