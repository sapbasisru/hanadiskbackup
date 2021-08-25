Конфигурирование системной БД HANA для работы скрипта hanadiskbackup
===

>[!NOTE]
>:point_up: Команды выполняются на сервере HANA от имени учетной записи `<hana_sid>adm`.

Создать пользователя резервного копирования HANA
---

Для запуска команд создания резервной копии БД HANA
с помощью скрипта `hanadiskbackup` в системной БД HANA
необходимо подготовить технического пользователя.

Далее используются переменные `HANABACKUP_USER_NAME` и `HANABACKUP_USER_PWD`
для обозначения имени учетной записи технического пользователя HANA и его пароля.

```bash
HANABACKUP_USER_NAME=TCU4BACKUP
HANABACKUP_USER_PWD=<Пароль пользователя TCU4BACKUP>
```

Далее даны команды для создания технического пользователя HANA `HANABACKUP_USER_NAME`.

Команды создания технического пользователя HANA
выполняются от имени административной учетной записи HANA.
Имя административной учетной записи будут обозначаться с помощью переменных
`SYSTEMDB_ADM_USER_NAME` и `SYSTEMDB_ADM_USER_PWD` соответственно.

Определить административную учетную запись и пароль в системной БД:

```bash
SYSTEMDB_ADM_USER_NAME=SYSTEM
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
```

Ниже приведены команды, предоставляющие техническому пользователю дополнительные полномочия,
позволяющие выполнять останов/запуск и восстановления прикладных тенантов HANA.
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
echo HANA_NAMESERVER_PORT is "$HANA_NAMESERVER_PORT"
```

Определить и визуально проверить хост сервера HANA:

```bash
HANA_HOST=$(basename $SAP_RETRIEVAL_PATH)
echo HANA_HOST is "$HANA_HOST"
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

Проверить работу скрипта `hanadiskbackup`:

/opt/hanadiskbackup/hanadiskbackup.sh --dbs SYSTEMDB --backup_type '-'