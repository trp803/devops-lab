# Ansible — автоматизация настройки серверов

## Что такое Ansible и зачем он нужен

Представьте: нужно настроить 50 серверов — установить Docker, настроить Nginx, создать пользователей. Делать это вручную по SSH — долго, легко ошибиться, невозможно воспроизвести точно.

**Ansible** — инструмент автоматизации который описывает желаемое состояние серверов в YAML файлах (плейбуках) и приводит серверы к этому состоянию.

**Ключевые принципы:**

**Agentless (без агентов)** — Ansible подключается по SSH, не нужно устанавливать ничего на серверах (только Python).

**Идемпотентность** — можно запускать плейбук много раз, результат всегда одинаковый. Если пакет уже установлен — Ansible не будет его переустанавливать.

**Декларативность** — описываем что должно быть (Docker установлен, запущен), а не как это сделать.

---

## Архитектура Ansible

```
Control Node (ваш компьютер или CI сервер)
│
│ SSH
├──► Сервер 1 (webserver1)
├──► Сервер 2 (webserver2)
└──► Сервер 3 (webserver3)
```

Ansible запускается на **control node** и подключается к **managed nodes** по SSH. На managed nodes нужен только Python.

---

## Inventory — список серверов

```ini
# inventory.ini

[webservers]           # Группа серверов
server1.example.com
server2.example.com
192.168.1.10

[databases]
db1.example.com ansible_user=ubuntu ansible_port=2222

[webservers:vars]      # Переменные для группы
ansible_user=ubuntu
```

Запуск плейбука для конкретной группы:
```bash
ansible-playbook -i inventory.ini site.yml --limit webservers
```

В нашем проекте используется `localhost ansible_connection=local` — Ansible управляет локальной машиной без SSH.

---

## Плейбуки (Playbooks)

Плейбук — YAML файл который описывает что сделать и на каких серверах.

```yaml
---
- name: Описание что делаем      # Название play
  hosts: webservers               # На каких серверах
  become: yes                     # sudo

  vars:                           # Переменные
    app_port: 8080

  tasks:                          # Список задач
    - name: Установить nginx
      apt:
        name: nginx
        state: present

    - name: Запустить nginx
      systemd:
        name: nginx
        state: started
        enabled: yes
```

---

## Модули Ansible

Ansible выполняет задачи через **модули** — готовые функции для конкретных операций:

| Модуль | Назначение | Пример |
|---|---|---|
| `apt` | Управление пакетами (Ubuntu/Debian) | Установить/удалить пакет |
| `yum` | Управление пакетами (CentOS/RHEL) | Установить/удалить пакет |
| `file` | Файлы и директории | Создать папку, изменить права |
| `copy` | Копировать файл на сервер | Скопировать конфиг |
| `template` | Jinja2 шаблон → файл | Сгенерировать конфиг с переменными |
| `systemd` | Управление systemd сервисами | Запустить/остановить/включить |
| `user` | Управление пользователями | Создать пользователя, добавить в группу |
| `shell` | Выполнить shell команду | Произвольные команды |
| `docker_container` | Управление Docker контейнерами | Запустить/остановить контейнер |
| `debug` | Вывод информации | Показать переменную |

### Пример модуля apt (идемпотентность)

```yaml
- name: Установить Docker
  apt:
    name: docker-ce
    state: present    # present = установить если нет
                      # absent = удалить если есть
                      # latest = обновить до последней версии
```

Если Docker уже установлен — Ansible ничего не делает и выводит `ok` вместо `changed`.

---

## Роли (Roles)

Роль — способ структурировать и переиспользовать плейбуки. Роль = набор задач, шаблонов и переменных для определённой цели.

```
roles/
└── webserver/
    ├── tasks/
    │   └── main.yml      # Задачи роли
    ├── templates/
    │   └── index.html.j2 # Jinja2 шаблоны
    ├── vars/
    │   └── main.yml      # Переменные роли
    ├── handlers/
    │   └── main.yml      # Обработчики событий
    └── defaults/
        └── main.yml      # Переменные по умолчанию
```

Применение роли в плейбуке:
```yaml
- hosts: webservers
  roles:
    - webserver     # Запускает roles/webserver/tasks/main.yml
    - docker        # Запускает roles/docker/tasks/main.yml
```

---

## Jinja2 шаблоны

Jinja2 — шаблонизатор для генерации файлов с переменными:

```html
<!-- templates/index.html.j2 -->
<!DOCTYPE html>
<html>
<body>
  <h1>{{ app_name }}</h1>          <!-- Переменная из vars -->
  <p>Сервер: {{ inventory_hostname }}</p>  <!-- Встроенная переменная Ansible -->

  {% if environment == "prod" %}   <!-- Условие -->
    <p>Production</p>
  {% endif %}

  {% for item in items %}          <!-- Цикл -->
    <li>{{ item }}</li>
  {% endfor %}
</body>
</html>
```

Ansible генерирует файл подставляя реальные значения переменных.

---

## register и debug — сохранение результатов

```yaml
- name: Проверить контейнер
  shell: docker ps | grep webapp
  register: result           # Сохраняем вывод команды

- name: Показать результат
  debug:
    msg: "{{ result.stdout }}"    # result.stdout — вывод команды
    # result.rc — код возврата (0 = успех)
    # result.stderr — stderr вывод
```

---

## Handlers — обработчики

Handlers запускаются только если задача что-то изменила (`changed`), и только один раз в конце play:

```yaml
tasks:
  - name: Изменить конфиг nginx
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: reload nginx     # Триггер для handler

handlers:
  - name: reload nginx
    systemd:
      name: nginx
      state: reloaded        # Перезагрузить только если конфиг изменился
```

Без handlers пришлось бы всегда перезапускать nginx — даже когда конфиг не менялся.

---

## Запуск Ansible

```bash
# Запустить плейбук
ansible-playbook -i inventory.ini site.yml

# Dry run (проверить без применения)
ansible-playbook -i inventory.ini site.yml --check

# Только конкретные задачи (по тегам)
ansible-playbook -i inventory.ini site.yml --tags "docker,nginx"

# Verbose (подробный вывод)
ansible-playbook -i inventory.ini site.yml -v

# Проверить подключение к серверам
ansible all -i inventory.ini -m ping
```

---

## Вывод Ansible

```
TASK [Установить Docker] ********************
ok: [server1]      # Уже установлен, ничего не делаем
changed: [server2] # Установили
failed: [server3]  # Ошибка
```

Итог в конце:
```
PLAY RECAP *********************************
server1 : ok=5  changed=2  unreachable=0  failed=0
server2 : ok=5  changed=3  unreachable=0  failed=0
```
