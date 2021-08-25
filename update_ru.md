Обновление скрипта hanadiskbackup
=================================

Команды, приведенные ниже, могут использоваться для обновления скрипта `hanadiskbackup.sh`.
Предполагается, что первоначальная инсталляция скрипта уже выполнена с помощью командного файла
[install_ru.md](install_ru.md).

>[!NOTE] :point_up:
>Команды выполняются на сервере HANA от имени учетной записи `root`.

Обновить Git-репозиторий
------------------------

В дальнейшем предполагается,
что переменная `HB_REPO_DIR` указывает на папку с локальной копией Git-репозитория.
Предположим, что используется путь
`/stage/sapbasisru.github/hanadiskbackup.git`.

```bash
HB_REPO_DIR=/stage/sapbasisru.github/hanadiskbackup.git
```

Обновить репозиторий
[hanadiskbackup.git](https://github.com/sapbasisru/hanadiskbackup.git)
с GitHub:

```bash
( cd $HB_REPO_DIR && git pull origin main )
```

Обновить скрипт
---------------

Далее используется переменная `HB_SCRIPT_DIR` для указания папки исполняемых файлов:

```bash
HB_SCRIPT_DIR=/opt/hanadiskbackup
```

В папку исполняемых файлов необходимо скопировать скрипт
`opt/hanadiskbackup/hanadiskbackup.sh`
из обновленной ранее локальной копии репозитория:

```bash
cp $HB_REPO_DIR/opt/hanadiskbackup/hanadiskbackup.sh $HB_SCRIPT_DIR
```

Протестировать запуск скрипта `hanadiskbackup.sh`:

```sh
$HB_SCRIPT_DIR/hanadiskbackup.sh --help
```
