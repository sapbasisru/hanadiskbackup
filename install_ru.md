Инсталляция скрипта hanadiskbackup
==================================

>[!NOTE] :point_up:
>Команды выполняются на сервере HANA от имени учетной записи `root`.

Загрузить Git-репозиторий
-------------------------

Для использования скрипта `hanadiskbackup` потребуется загрузить репозиторий
`https://github.com/sapbasisru/hanadiskbackup.git`
с GitHub.
Загрузить репозиторий можно либо с помощью команды `git clone`, либо другими средствами.

В дальнейшем предполагается,
что переменная `HB_REPO_DIR` указывает на папку с локальной копией Git-репозитория.
Предположим, что используется путь
`/stage/sapbasisru.github/hanadiskbackup.git`.

```bash
HB_REPO_DIR=/stage/sapbasisru.github/hanadiskbackup.git
```

Скопировать репозиторий [hanadiskbackup.git](https://github.com/sapbasisru/hanadiskbackup.git):

```bash
git clone --depth 1 https://github.com/sapbasisru/hanadiskbackup.git $HB_REPO_DIR
```

Подготовить папку для исполняемых файлов
----------------------------------------

Для размещения скрипта рекомендуется использовать папку
`/opt/hanadiskbackup`.
Далее используется переменная `HB_SCRIPT_DIR` для указания папки исполняемых файлов:

```bash
HB_SCRIPT_DIR=/opt/hanadiskbackup
```

Подготовить папку исполняемых файлов:

```bash
[[ ! -d $HB_SCRIPT_DIR ]] && \
    ( mkdir $HB_SCRIPT_DIR && chgrp sapsys $HB_SCRIPT_DIR && chmod 775 $HB_SCRIPT_DIR )
ls -ld $HB_SCRIPT_DIR
```

В папку исполняемых файлов необходимо скопировать скрипт
`opt/hanadiskbackup/hanadiskbackup.sh`
из подготовленной ранее локальной копии репозитория.

```bash
cp $HB_REPO_DIR/opt/hanadiskbackup/hanadiskbackup.sh $HB_SCRIPT_DIR
chgrp sapsys $HB_SCRIPT_DIR/hanadiskbackup.sh
chmod 755 $HB_SCRIPT_DIR/hanadiskbackup.sh
```

Протестировать запуск скрипта `hanadiskbackup.sh`:

```sh
$HB_SCRIPT_DIR/hanadiskbackup.sh --help
```

Подготовить папку журналов работы
---------------------------------

Для записи журналов работы скрипт, по умолчанию,
использует папку `/var/opt/hanadiskbackup`.
Можно использовать другую папку для записи журналов.
Нестандартное расположение папки задается с помощью опции `--log-dir` при старте скрипта.

```bash
HB_LOG_DIR=/var/opt/hanadiskbackup
```

Подготовить папку журналов работы:

```bash
[[ -d $HB_LOG_DIR ]] || \
    ( mkdir $HB_LOG_DIR && chgrp sapsys $HB_LOG_DIR && chmod 775 $HB_LOG_DIR )
ls -ld $HB_LOG_DIR
```
