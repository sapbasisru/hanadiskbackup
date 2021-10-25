Конфигурирование системной БД HANA для работы скрипта hanadiskbackup
===

Предполагается, что инсталляция скрипта `hanadiskbackup` уже выполнена с помощью командного файла
[install_ru.md](install_ru.md).

>[!NOTE]
>:point_up: Команды выполняются на сервере HANA от имени учетной записи `<hana_sid>adm`.

Подготовить окружение для выполнения команд
---

Определить папки скрипта `hanadiskbackup`:

```bash
HB_SCRIPT_DIR=/opt/hanadiskbackup
HB_LOG_DIR=/var/opt/hanadiskbackup
```

Создать пользователя резервного копирования HANA
---

Для запуска команд создания резервной копии БД HANA
с помощью скрипта `hanadiskbackup` в системной БД HANA
необходимо подготовить технического пользователя.

Далее используются переменные `HANABACKUP_USER_NAME` и `HANABACKUP_USER_PWD`
для обозначения имени учетной записи технического пользователя HANA и его пароля.
Установить имя технического пользователя:

```bash
HANABACKUP_USER_NAME=TCU4BACKUP
```

Установить пароль технического пользователя:

```bash
HANABACKUP_USER_PWD=<Пароль пользователя TCU4BACKUP>
```

Далее даны команды для создания технического пользователя HANA `HANABACKUP_USER_NAME`.

Команды создания технического пользователя HANA
выполняются от имени административной учетной записи HANA.
Имя административной учетной записи будут обозначаться с помощью переменных
`SYSTEMDB_ADM_USER_NAME` и `SYSTEMDB_ADM_USER_PWD` соответственно.

Установить имя административной учетной записи в системной БД:

```bash
SYSTEMDB_ADM_USER_NAME=SYSTEM
```

Установить пароль административной учетной записи:

```bash
SYSTEMDB_ADM_USER_PWD=<Пароль пользователя SYSTEM>
```

Создание учетной записи будет выполнено с помощью утилиты командной строки `hdbsql`.
Подготовить и протестировать команду запуска `hdbsql`:

```bash
HDBSQL="${DIR_EXECUTABLE}/hdbsql -d SYSTEMDB -n localhost -i ${TINSTANCE} -u $SYSTEMDB_ADM_USER_NAME -p \"${SYSTEMDB_ADM_USER_PWD}\" -j"
$HDBSQL "SELECT * FROM DUMMY"
```

Создать технического пользователя `HANABACKUP_USER_NAME` и предоставить ему необходимые полномочия:

```bash
$HDBSQL "CREATE USER $HANABACKUP_USER_NAME password \"${HANABACKUP_USER_PWD}\" NO FORCE_FIRST_PASSWORD_CHANGE"
$HDBSQL "ALTER USER $HANABACKUP_USER_NAME DISABLE PASSWORD LIFETIME"
$HDBSQL "GRANT CATALOG READ TO $HANABACKUP_USER_NAME"
$HDBSQL "GRANT BACKUP OPERATOR to $HANABACKUP_USER_NAME"
$HDBSQL "GRANT BACKUP ADMIN to $HANABACKUP_USER_NAME"
$HDBSQL "GRANT DATABASE BACKUP OPERATOR to $HANABACKUP_USER_NAME"
$HDBSQL "GRANT DATABASE BACKUP ADMIN to $HANABACKUP_USER_NAME"
```

Ниже приведены команды, предоставляющие техническому пользователю дополнительные полномочия,
позволяющие выполнять останов/запуск и восстановление прикладных тенантов HANA.
Эти полномочия **не требуются** для работы скрипта `hanadiskbackup`.

```bash
$HDBSQL "GRANT DATABASE STOP TO $HANABACKUP_USER_NAME"
$HDBSQL "GRANT DATABASE START TO $HANABACKUP_USER_NAME"
$HDBSQL "GRANT DATABASE RECOVERY OPERATOR TO $HANABACKUP_USER_NAME"
```

Создать ключ в HANA Secure User Store
---

Скрипт `hanadiskbackup` использует *HANA Secure User Store* для определения пользователя и его пароля,
от имени которого будут запускаться команды в БД HANA.

Кроме имени пользователя и его пароля,
запись в *HANA Secure User Store* должна содержать имя хост и порт для подколючения к контейнеру HANA.

Определить и визуально проверить порт сервиса HANA `nameserver`:

```bash
HANA_NAMESERVER_PORT=$($HDBSQL -C -a -x "SELECT SQL_PORT FROM SYS_DATABASES.M_SERVICES WHERE DATABASE_NAME='SYSTEMDB' AND SERVICE_NAME='nameserver' AND COORDINATOR_TYPE= 'MASTER'")
echo "`tput setaf 2`HANA nameserver port is`tput sgr0` : [`tput setaf 1`$HANA_NAMESERVER_PORT`tput sgr0`]"
```

Определить и визуально проверить хост сервера HANA:

```bash
HANA_HOST=$(basename $SAP_RETRIEVAL_PATH)
echo "`tput setaf 2`HANA host is`tput sgr0` : [`tput setaf 1`$HANA_HOST`tput sgr0`]"
```

Создать ключ для технической учетной записи пользователя `HANABACKUP_USER_NAME` в *HANA Secure User Store*:

```bash
hdbuserstore LIST KEY4BACKUP
hdbuserstore SET KEY4BACKUP $HANA_HOST:$HANA_NAMESERVER_PORT $HANABACKUP_USER_NAME $HANABACKUP_USER_PWD
hdbuserstore LIST KEY4BACKUP
```

Проверить подключение к HANA с использованием записи в *HANA Secure User Store*:

```bash
${DIR_EXECUTABLE}/hdbsql -j -U KEY4BACKUP "SELECT * FROM DUMMY"
```

Проверить работу скрипта `hanadiskbackup` с помощью следующей команды
(команда не выполняет реального создания резервной копии БД):

```bash
$HB_SCRIPT_DIR/hanadiskbackup.sh --dbs SYSTEMDB --backup_type '-'
```

Запустить сессию резервного копирования
---

Запустить реальную сессию резервного копирования системной БД и всех прикладных тенантов HANA:

```bash
$HB_SCRIPT_DIR/hanadiskbackup.sh
```

Запланировать запуск скрипта через *crontab*
---

Скрипт `hanadiskbackup` может быть запущен в режиме недельного расписания
с помощью специального формата параметра `--backup_type`.
Например,
для создания полной резервной копии  один раз в неделю в воскресенье и
создания дифференциальных резервных копий в другие дни необходимо указать
`wM:ddddddc`.

Добавить в планировщик ОС `crontab` ежедневный запуск скрипта `hanadiskbackup` в два часа ночи в режиме недельного расписания:

```bash
( crontab -l ; \
cat<<EOF
# Start HANA disk backup for HANA MDC $SAPSYSTEMNAME 
0 2 * * * $HB_SCRIPT_DIR/hanadiskbackup.sh --backup_type w:cdddddd > $HB_LOG_DIR/hanadiskbackupcron_${SAPSYSTEMNAME}.txt 2>&1
EOF
) | crontab -
```

Визуально проверить расписание планировщика `crontab`:

```bash
crontab -l
```

Решение технических проблем
---

### Анализ ошибки HANA 258: insufficient privilege

Если при запуске SQL-команды возникает ошибка *258: insufficient privilege...*,
детали ошибки можно получить с помощью SQL-команды *CALL SYS.GET_INSUFFICIENT_PRIVILEGE_ERROR_DETAILS ('\<guid\>', ?)":

```bash
$HDBSQL "CALL SYS.GET_INSUFFICIENT_PRIVILEGE_ERROR_DETAILS ('<guid>', ?)"
```
