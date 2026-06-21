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

```mermaid
flowchart TB
    subgraph host["Host Machine (ASUS/G750JX)"]
        subgraph hv["Hypervisor (Libvirt / KVM)"]
            subgraph runner_node["runner-builder VM<br/>IP: 192.168.56.10"]
                runner_svc["gitlab-runner<br/>(Daemon)"]
                docker_build["docker-engine<br/>(Docker Daemon)"]
                socket_runner[("UNIX Socket<br/>/var/run/docker.sock")]
                runner_svc -.uses.-> socket_runner
                docker_build -.listens.-> socket_runner
            end

            subgraph prod_node["production-node VM<br/>IP: 192.168.56.11"]
                docker_prod["docker-engine<br/>(Docker Daemon)"]
                subgraph bridge["Docker Bridge Network"]
                    container_app["bsuir-app<br/>(Flask Container)"]
                    container_wt["watchtower<br/>(Updater Container)"]
                end
                docker_prod --> container_app
                docker_prod --> container_wt
            end
        end
    end

    subgraph cloud["GitLab Cloud"]
        registry[("GitLab Container<br/>Registry")]
        gitlab_engine["GitLab CI/CD<br/>Engine"]
    end

    runner_svc -->|"Long Polling (HTTPS)"| gitlab_engine
    docker_build -->|"docker push"| registry
    container_wt -->|"docker pull"| registry
    runner_svc -->|"HTTP POST /v1/update (8080)"| container_wt
```

### 2. UML Диаграмма взаимодействия (Sequence Diagram)

```mermaid
sequenceDiagram
    autonumber
    actor dev as Разработчик
    participant gitlab as GitLab Репозиторий
    participant runner as runner-builder<br/>(192.168.56.10)
    participant registry as GitLab Registry
    participant prod as production-node<br/>(192.168.56.11)

    Note over dev,prod: Этап разработки и сборки (Ветка feature)
    dev->>gitlab: git push (feature/cpu-metrics)
    gitlab->>runner: Триггер джобы build_job (модель Pull)
    activate runner
    runner->>runner: docker build -t bsuir-app:latest ./python/
    runner->>registry: docker login & docker push
    deactivate runner

    Note over dev,prod: Этап деплоя (Слияние в ветку main)
    dev->>gitlab: Создание & Апрув Merge Request в main
    gitlab->>runner: Триггер джобы deploy_job
    activate runner
    runner->>prod: curl -X POST http://192.168.56.11:8080/v1/update
    activate prod
    Note over prod: Агент Watchtower принимает вебхук
    prod-->>runner: HTTP 200 OK
    deactivate runner

    prod->>registry: docker pull bsuir-app:latest
    prod->>prod: Перезапуск контейнера bsuir-app (Порт 80)
    deactivate prod
```

### 3. Структурная схема сетевых потоков данных

```mermaid
flowchart LR
    subgraph ext["Внешняя сеть (Интернет)"]
        gl_core["GitLab.com Core Engine"]
        gl_reg[("registry.gitlab.com")]
    end

    subgraph local["Локальный контур виртуализации (192.168.56.0/24)"]
        subgraph runner_box["Node: runner-builder (192.168.56.10)"]
            build_agent["gitlab-runner agent"]
            build_cli["docker build client"]
        end
        subgraph prod_box["Node: production-node (192.168.56.11)"]
            wt_agent["watchtower container"]
            flask_app["bsuir-app web container"]
        end
    end

    build_agent -->|"HTTPS 443<br/>Опрос задач / Long Polling"| gl_core
    build_cli -->|"HTTPS 443<br/>Доставка образа"| gl_reg
    build_agent -->|"HTTP 8080<br/>Вебхук /v1/update"| wt_agent
    wt_agent -->|"HTTPS 443<br/>Скачивание образа"| gl_reg
    wt_agent -->|"Docker API<br/>Перезапуск контейнера"| flask_app
```