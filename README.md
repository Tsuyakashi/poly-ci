# Автоматизированная система интеграции и развертывания веб-приложения (Flask)

Данный репозиторий содержит лабораторный проект (Контрольная работа) по дисциплине, моделирующий полный цикл CI/CD в соответствии с методологией DevOps.

## Стек технологий и исходные данные
* **Вариант:** №6
* **Платформа VCS:** GitLab
* **Язык приложения:** Python (Flask)
* **Стратегия ветвления:** GitHub Flow
* **Инфраструктура:** IaC (Vagrant + Libvirt / KVM)
* **Целевая ОС виртуалки:** Ubuntu 24.04 LTS

---

## Архитектура стенда (Infrastructure as Code)

Развертывание тестовой среды полностью автоматизировано с помощью Vagrantfile мульти-нодовой конфигурации. Инфраструктура разделена на два изолированных узла, связанных приватной сетью (192.168.56.0/24):

1. **runner-builder (IP: 192.168.56.10)** Выделенный агент сборки. На борту развернут демон gitlab-runner и docker-engine. Сборка контейнеров изолирована и происходит по схеме проброса докер-сокета (/var/run/docker.sock) внутрь контейнера-сборщика.
2. **production-node (IP: 192.168.56.11)** Целевой сервер приложений (Продакшн). Содержит запущенное веб-приложение на порту 80 и легковесный агент Watchtower HTTP API, ожидающий хуков на обновление образов без прямого SSH-доступа со стороны CI/CD.

---

## Реализованный CI/CD Пайплайн (.gitlab-ci.yml)

Жизненный цикл изменений описывается двумя стадиями согласно стратегии бранчинга GitHub Flow:

### 1. Стадия build (Сборка и доставка)
* Срабатывает при любых пушах в репозиторий и при создании Merge Request.
* Использует изолированное окружение на базе образа docker:26.1.4.
* Выполняет авторизацию во встроенном GitLab Container Registry.
* Собирает обновленный Docker-образ Flask-приложения из директории ./python/ и пушит его в приватный реестр с тегом :latest.

### 2. Стадия deploy (Непрерывное развертывание)
* Запускается автоматически только при слиянии изменений в ветку main.
* Использует микроконтейнер curlimages/curl:latest.
* Отправляет авторизованный POST-запрос на вебхук агента автоматического обновления:  
  POST http://192.168.56.11:8080/v1/update
* Watchtower на продакшн-ноде перехватывает запрос, скачивает свежий образ из GitLab Registry, бесшовно гасит старый контейнер bsuir-app и запускает обновленную версию.

---

## Реализованная фича (Новый функционал)

В рамках GitHub Flow в ветке feature/cpu-metrics базовое демонстрационное приложение было доработано. Добавлен динамический DevOps-интерфейс, выводящий:
1. Текущий серверный таймстамп выполнения запроса контейнером (datetime).
2. Актуальную системную метрику загрузки процессора за последнюю минуту (System Load 1 min), считываемую напрямую из системного интерфейса ядра Linux /proc/loadavg.

---

## Инструкция по развертыванию и запуску локально

### Шаг 1: Подготовка окружения
Создайте локальный файл переменных окружения .env в корне проекта на хосте:
```
GITLAB_TOKEN=your_gitlab_runner_registration_token
WATCHTOWER_TOKEN=secure_secret_token_for_webhooks
REGISTRY_USER=your_gitlab_username
REGISTRY_PASSWORD=your_gitlab_personal_access_token
APP_IMAGE=registry.gitlab.com/your_username/your_repo:latest
```

### Шаг 2: Поднятие инфраструктуры
Запустите создание и конфигурацию виртуальных машин через Vagrant:
```
vagrant up --provider=libvirt
```
Скрипты provision-секции автоматически установят Docker, скачают и зарегистрируют GitLab-runner на хосте сборщика, настроят права доступа и поднимут Watchtower на прод-сервере.

### Шаг 3: Проверка работы
* Проверить статус раннера в интерфейсе GitLab (Settings -> CI/CD -> Runners).
* Веб-интерфейс развернутого приложения доступен по адресу: http://192.168.56.11:80.

## UML-диаграммы и структурные схемы для пояснительной записки

### 1. UML Диаграмма развертывания (Deployment Diagram)

```
@startuml
skinparam backgroundColor #ffffff
skinparam componentStyle uml2

node "Host Machine (ASUS/G750JX)" {
    node "Hypervisor (Libvirt / KVM)" {
        
        node "runner-builder VM\nIP: 192.168.56.10" as runner_node {
            component "gitlab-runner\n(Daemon)" as runner_svc
            component "docker-engine\n(Docker Daemon)" as docker_build
            file "UNIX Socket\n/var/run/docker.sock" as socket_runner
            runner_svc ..> socket_runner : uses
            docker_build ..> socket_runner : listens
        }
        
        node "production-node VM\nIP: 192.168.56.11" as prod_node {
            component "docker-engine\n(Docker Daemon)" as docker_prod
            
            node "Docker Bridge Network" {
                component "bsuir-app\n(Flask Container)" as container_app
                component "watchtower\n(Updater Container)" as container_wt
            }
            docker_prod --> container_app
            docker_prod --> container_wt
        }
    }
}

cloud "GitLab Cloud" {
    database "GitLab Container\nRegistry" as registry
    component "GitLab CI/CD\nEngine" as gitlab_engine
}

runner_svc --> gitlab_engine : Long Polling (HTTPS)
docker_build --> registry : docker push
container_wt --> registry : docker pull
runner_svc --> container_wt : HTTP POST /v1/update (Port 8080)
@endum
```

### 2. UML Диаграмма взаимодействия (Sequence Diagram)

```
@startuml
autonumber
skinparam backgroundColor #ffffff

actor "Разработчик" as dev
participant "GitLab Репозиторий" as gitlab
participant "runner-builder\n(192.168.56.10)" as runner
participant "GitLab Registry" as registry
participant "production-node\n(192.168.56.11)" as prod

== Этап разработки и сборки (Ветка feature) ==
dev -> gitlab : git push (feature/cpu-metrics)
gitlab -> runner : Триггер джобы build_job (модель Pull)
activate runner
runner -> runner : docker build -t bsuir-app:latest ./python/
runner -> registry : docker login & docker push
deactivate runner

== Этап деплоя (Слияние в ветку main) ==
dev -> gitlab : Создание & Апрув Merge Request в ветку main
gitlab -> runner : Триггер джобы deploy_job
activate runner
runner -> prod : curl -X POST http://192.168.56.11:8080/v1/update
activate prod
note over prod : Агент Watchtower\nпринимает вебхук
runner <-- prod : HTTP 200 OK
deactivate runner

prod -> registry : docker pull bsuir-app:latest
prod -> prod : Перезапуск контейнера bsuir-app (Порт 80)
deactivate prod
@endum
```

### 3. Структурная схема сетевых потоков данных

```
@startuml
skinparam backgroundColor #ffffff
allow_mixing

package "Внешняя сеть (Интернет)" {
    component [GitLab.com Core Engine] as gl_core #lightcyan
    database [registry.gitlab.com] as gl_reg #lightcyan
}

package "Локальный контур виртуализации (Private Network 192.168.56.0/24)" {
    
    package "Node: runner-builder (192.168.56.10)" {
        [gitlab-runner agent] as build_agent
        [docker build client] as build_cli
    }
    
    package "Node: production-node (192.168.56.11)" {
        [watchtower container] as wt_agent #lightpoint
        [bsuir-app web container] as flask_app
    }
}

' Потоки трафика
build_agent --> gl_core : HTTPS (443/tcp) \n[Опрос задач / Long Polling]
build_cli --> gl_reg : HTTPS (443/tcp) \n[Доставка собранного образа]

build_agent --> wt_agent : HTTP (8080/tcp) \n[Локальный вебхук деплоя /v1/update]

wt_agent --> gl_reg : HTTPS (443/tcp) \n[Скачивание обновленного образа]
wt_agent --> flask_app : Docker API \n[Бесшовный перезапуск контейнера]
@endum
```