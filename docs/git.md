# Git (Infra Repo)

## Первый коммит

```bash
git init
git switch -c main
git add -A
git commit -m "infra: docker dev stack"
```

## Проверка перед пушем

```bash
docker compose config >/dev/null
git status --short
```

## Пуш

```bash
git remote add origin git@github.com:USER/REPO.git
git push -u origin main
```

## Ежедневный цикл

```bash
git status
git add -A
git commit -m "infra: update"
git push
```
