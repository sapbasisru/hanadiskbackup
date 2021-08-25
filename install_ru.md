Инсталляция скрипта hanabackup
==============================

>[!NOTE]
>:point_up: Команды выполняются на сервере HANA от имени учетной записи `root`.

Загрузить Git-репозиторий
-------------------------

Для использования скрипта `hanabackup` потребуется загрузить репозиторий
`https://github.com/sapbasisru/hanabackup.git`
с GitHub:

- `https://github.com/sapbasisru/hanacleaner.git` - репозиторий, содержащий python-скрипт HANACleaner (`hanacleaner.py`).
- `https://github.com/sapbasisru/hanacleaner_helper.git` - репозиторий, содержащий скрипт-исполнитель и подготовленные конфигурационные файлы.

Загрузить репозиторий можно либо с помощью команды `git clone` или другими средствами.

В дальнейшем предполагается,
что переменные `HC_REPO_DIR` и `HCH_REPO_DIR` указывают на папки с локальными копиями репозиториев.
Предположим, что используются пути
`/stage/sapbasisru.github/hanacleaner.git` и
`/stage/sapbasisru.github/hanacleaner_helper.git` соответственно:

```bash
HC_REPO_DIR=/stage/sapbasisru.github/hanacleaner.git
HCH_REPO_DIR=/stage/sapbasisru.github/hanacleaner_helper.git
```

Скопировать репозиторий [hanacleaner.git](https://github.com/sapbasisru/hanacleaner.git):

```bash
git clone https://github.com/sapbasisru/hanacleaner.git $HC_REPO_DIR
```

Скопировать репозиторий [hanacleaner_helper.git](https://github.com/sapbasisru/hanacleaner_helper.git):

```bash
git clone https://github.com/sapbasisru/hanacleaner_helper.git $HCH_REPO_DIR
```



Подготовить папку для исполняемых файлов
----------------------------------------

Подготовить папку журналов работы
---------------------------------
