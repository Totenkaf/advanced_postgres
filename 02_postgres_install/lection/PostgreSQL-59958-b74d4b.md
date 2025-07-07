# Virtual Machines (Compute Cloud) https://cloud.yandex.ru/docs/free-trial/

Создание виртуальной машины:
https://cloud.yandex.ru/docs/compute/quickstart/quick-create-linux

name vm: otus-db-pg-vm-1

Создать сеть:
Каталог: default
Имя: otus-vm-db-pg-net-1

Доступ
username: otus

настройка OpenSSH в Windows
Параметры -> Система -> Дополнительные компоненты -> клиент Open SSH (добавить)
Службы (Service) -> OpenSSH SSH Server (запустить)


Сгенерировать ssh-key:
```bash
ssh-keygen -t rsa -b 2048
name ssh-key: yc_key
chmod 600 ~/.ssh/yc_key.pub
ls -lh ~/.ssh/
cat ~/.ssh/yc_key.pub # в Windows C:\Users\<имя_пользователя>\.ssh\yc_key.pub
```
Подключение к VM:
https://cloud.yandex.ru/docs/compute/operations/vm-connect/ssh

```bash
ssh -i ~/yc_key otus@51.250.35.42 # в Windows ssh -i <путь_к_ключу/имя_файла_ключа> <имя_пользователя>@<публичный_IP-адрес_виртуальной_машины>

Установка Postgres:
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql && sudo apt install unzip && sudo apt -y install mc

pg_lsclusters

Установить пароль для Postgres:
sudo -u postgres psql
\password   #12345
\q

Добавить сетевые правила для подключения к Postgres:
cd /etc/postgresql/17/main/
sudo nano /etc/postgresql/17/main/postgresql.conf
#listen_addresses = 'localhost'
listen_addresses = '*'

sudo nano /etc/postgresql/17/main/pg_hba.conf
#host    all             all             127.0.0.1/32            scram-sha-256 password
host    all             all             0.0.0.0/0               scram-sha-256 

sudo pg_ctlcluster 17 main restart

Подключение к Postgres:
psql -h 51.250.35.42 -U postgres

\l

------ установка в ЯО через команды

'yc' в составе Яндекс.Облако CLI для управления облачными ресурсами в Яндекс.Облако
https://cloud.yandex.com/en/docs/cli/quickstart

Подключаемся к Яндекс.Облако и выполняем конфигурацию окружения с помощью команды:
yc init

Проверяем установленную версию 'yc' (рекомендуется последняя доступная версия):
yc version

Список географических регионов и зон доступности для размещения VM:
yc compute zone list
yc config set compute-default-zone ru-central1-a && yc config get compute-default-zone

Далее будем использовать географический регион ‘ru-central1’ и зону доступности 'ru-central1-a'.

Список доступных типов дисков:
yc compute disk-type list

Далее будем использовать тип диска ‘network-hdd’.

Создаем сетевую инфраструктуру для VM:

yc vpc network create \
    --name otus-net \
    --description "otus-net" \

yc vpc network list

yc vpc subnet create \
    --name otus-subnet \
    --range 192.168.0.0/24 \
    --network-name otus-net \
    --description "otus-subnet" \

yc vpc subnet list

Сгенерируем ssh-key:
ssh-keygen -t rsa -b 2048
ssh-add ~/.ssh/yc_key

Устанавливаем ВМ:
yc compute instance create \
    --name otus-vm \
    --hostname otus-vm \
    --cores 2 \
    --memory 4 \
    --create-boot-disk size=15G,type=network-hdd,image-folder-id=standard-images,image-family=ubuntu-2004-lts \
    --network-interface subnet-name=otus-subnet,nat-ip-version=ipv4 \
    --ssh-key ~/.ssh/yc_key.pub \

yc compute instances show otus-vm
yc compute instances list

Подключаемся к ВМ:
ssh -i ~/.ssh/yc_key yc-user@89.169.131.145

-- Установим PostgreSQL:
sudo apt update && sudo apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt -y install postgresql 

-- удаление
yc compute instance delete otus-vm && yc vpc subnet delete otus-subnet && yc vpc network delete otus-net

------ Обновление кластера
Более новая версия не содержит бинарники предыдущих, при создании кластера pg_createcluster 13 main, т.е. если мы хотим иметь на сервере несколько кластеров разных версий, нужно скачивать их бинарники. Соответственно чтобы обновиться с 15 на 16 версию, нужны бинарники обоих. Кластеры друг другу не мешают, у них разные директории и разные порты. Независимо друг от друга они могут включаться и выключаться.

pg_upgradecluster 12 main

для всех утилит есть мануал 
man pg_upgradecluster

-- переименуем старый кластер
sudo pg_renamecluster 12 main main12

-- заапдейтим версию кластера
sudo pg_upgradecluster 12 main12

pg_lsclusters

-- обратите внимание, что старый кластер остался. Давайте удалим его
sudo pg_dropcluster 12 main12


-------- Установка клиента PostgreSQL
sudo apt install postgresql-client
export PATH=$PATH:/usr/bin
psql --version

-------- Docker
docker search postgres

docker pull  postgres

docker images

docker run --rm --name postgres -e POSTGRES_PASSWORD=my_pass -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres 

docker ps 

docker exec -it postgres15 bash

su postgres

psql

docker stop CONTAINER_ID


- установка докера  
-- https://docs.docker.com/engine/install/ubuntu/
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && rm get-docker.sh && sudo usermod -aG docker $USER && newgrp docker


-- 1. Создаем docker-сеть: 
sudo docker network create pg-net

12e7df3eaf31b205191e60ad66b8b5e6a0e4bfa4e8aa6076330493a828a0060a

-- 2. подключаем созданную сеть к контейнеру сервера Postgres:
sudo docker run --name pg-server --network pg-net -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:15

-- 3. Запускаем отдельный контейнер с клиентом в общей сети с БД: 
sudo docker run -it --rm --network pg-net --name pg-client postgres:15 psql -h pg-server -U postgres

CREATE DATABASE otus; 

-- 4. Проверяем, что подключились через отдельный контейнер:
sudo docker ps -a

sudo docker stop 1aff1c9dbf97

sudo docker rm 1aff1c9dbf97

psql -h localhost -U postgres -d postgres

-- с ноута
psql -p 5432 -U postgres -h 89.169.146.12 -d otus -W


-- зайти внутрь контейнера (посмотреть использование дискового пространства файловой системы контейнера)
sudo docker exec -it pg-server bash
```