# Формула для развертывания внутреннего PKI

## Настройка мастера и миньонов

В настройках мастера надо разрешить одним миньонам отправлять запросы на подписание сертификатов к кругим миньонам, которые выполняют роль центра сертификации. Для этого добавляем в конфигурацию мастера

```yaml
peer:
  .*:
    - x509.sign_remote_certificate
```

Вместо `.*` можно указать другое регулярное выражение, если мы хотим разрешить запросы на подписание сертификатов не для всех миньонов, а только для некоторых.

## Принцип работы

Для работы нужно 2 - 3 миньона, хотя, технически все роли могут быть задействованы в пределах одного миньона.

* корневой центр сертифкации, (minion id будет `ca`), на этом миньоне выпускается "самый главный" приватный ключ и корневой сертификат, относительно которого выстраивается вся цепочка доверия, можно развернуть его как на salt-master сервере так и на отдельном, выделенном исключительно для этой цели, миньоне.
* промежуточный центр сертификации (minion id будет `int_ca`), служит для повышения безопасности и гибкости управления, технически прмежуточный цетр может распологаться на том же миньоне что и корневой центр сертификации.
* клиент (minion id `client`) которому необходим сертификат, это может быть любой миньон на котором запущен некий сервис требюующий сертификата для функционирования, например HTTPS веб сервер.

Солт использует классическую схему, клиент которому нужен сертификат, создает запрос к центру сертификации на подпись нового сертификата, если в политиках для клиента имеется разрешение на данную операцию, то центр сертификации подписывает сертификат.

## Доступные стейты

* [pki.common](#common)
* [pki.root](#root)
* [pki.root.ca](#root.ca)
* [pki.root.policies](#root.policies)
* [pki.intermediate](#intermediate)
* [pki.intermediate.ca](#intermediate.ca)
* [pki.intermediate.policies](#intermediate.policies)
* [pki.deploy_ca_certs](#deploy_ca_certs)
* [pki.issue](#issue)

### common

Данный стейт необходимо выполнять на каждом миньоне который будет использовать PKI, он отвечает за создание каталога для сертификатов и установку нпакетов необходимых для работы модуля Солт - `x509`

### root

Выполнит [pki.root.ca](#root.ca) и [pki.root.policies](#root.policies)

### root.ca

Стейт для создания корневого центра сертификации, на миньоне к которому будет применен данный стейт будет выпущен долгосрочный сертификат с параметрами необходимыми для корневого сертификата. Выпущенный сертификат будет опубликован в Salt Mine под алиасом `pki_root_ca` затем его можно получить из Mine используя `mine.get`

```bash
# на мастере
salt 'root_ca.minion.id' mine.get 'root_ca.minion.id' pki_root_ca

# на произвольном миньоне
salt-call mine.get 'root_ca.minion.id' pki_root_ca
```

### root.policies

Стейт для настройки политик подписи сертификатов по запросу от других миньонов. Политики задаются в файле [signing_policies/root.jinja](signing_policies/root.jinja), изначально досутпа только одна политика для подписи сертификатов промежуточных центров сертификации.

### intermediate

Выполнит [pki.intermediate.ca](#intermediate.ca) и [pki.intermediate.policies](#intermediate.policies)

### intermediate.ca

Стейт для настройки промежуточнх центров сертификатции, их может быть несколько, они могут быть на разных миньонах для повышения безопасности и для возможности инвалидации всех сертификатов выданных каким-либо отдельным промежуточным центром сертификации. К примеру, может быть промежуточный центр для внутренних сервисов, и отдельный центр сертификации для OpenVPN. Разные промежуточные центры сертификации могут иметь разные политики подписи. Например центр сертификации OpenVPN может выпускать только клиентские сертификаты, их нельзя будет использовать в качестве сертификата HTTP сервера.

### intermediate.policies

Стейт настраивает политики для выпуска конечных сертификатов: для сервисов и пользователей. Политики берутся из файла `signing_policies/<intermediate_name>.jinja` где `<intermediate_name>`это данные из пиллара `salt_pki.intermediate_ca.name`

### pki.deploy_ca_certs

Стейт предназначен для распространения доверенных корневых сертификатов на Debian based ОС.
Сертификаты помещаются в системное хранище корневых сертификатов, надо учитывать, что не не всё ПО использует его, к примеру, Java имеет собственное хранилище.
Стейт распространяет сертификаты выпущенные данной формулой, а так же дополнительные произвольные сертификаты из папки [ca_certs](ca_certs).

Для Debian, процедура взята из `/usr/share/doc/ca-certificates/README.Debian` описание происходящего "под капотом" нихже.

#### Добавление сертификата

* поместить файл с сертификатом в папку `/usr/local/share/ca-certificates`
* запустить `update-ca-certificates`, данная утилита создаст симлинки в `/etc/ssl/certs` и склееный файл со всеми доверенными сертификатами `/etc/ssl/certs/ca-certificates.crt` промежуточне сертификаты в этот файл похоже не попадают, только корневые

#### Удаление или замена сертификата

* удалить / заменть файл с сертификатом из папки /usr/local/share/ca-certificates/
* запустить `update-ca-certificates -f`, утилита удалит симлинки для отсутствующих файлов из `/etc/ssl/certs` и заново соберет `/etc/ssl/certs/ca-certificates.crt` так же без удаленных сертификатов

### pki.issue

На основе данных из пиллара `salt_pki.issue` выпускает сертификата для конечного "клиента" в качестве клиента обычно выступает некий сервис которому необходим сертификат.

`pki.issue` создает приватный ключ, выпускает подписанный сертификат и размещает его в каталоге для сертификатов `salt_pki.base_dir`, по умолчанию `/etc/pki` с помощью `include` подключается внешний стейт, который возьмет и подключит созданные файл к сервису, например скопирует их в каталог с конфигурационными файлами сервиса, обновит сами конфигурационные файлы.

К плюсам данного подхода можно отнести необходимость запускать лишь один стейт `pki.issue` дальше на основе данных из пилларов будут выполнены все необходимые действия, [пере]выпуск сертификатов, обновление конфигурации и перезапусе сервиса.
Из минусов нужно заметить небходимость указывать путь к приватному ключу и сертификату дважды, первый раз в пилларе для `pki.issue` (`sqlt_pki.issue.myservice.key.name`, `sqlt_pki.issue.myservice.cert.name`) притом здесь нужно указать путь относительно `salt_pki.base_dir` например `api/myservice.key` и `api/myservice.crt`, и второй раз в пилларах для сервиса которому этот сертификат предназначается, притом здесь уже нужно указывать абсолютный путь: `/etc/pki/api/myservice.key`, `/etc/pki/api/myservice.crt`.

Созданыне файлы могут быть использованы напрямую, без копирования их куда-либо еще, для этого сервис должен иметь возможность прочитать эти файлы, это возможно если сервис работает с правами суперпользователя (salt-master, salt-minion  и т.п.) или если для создаваемых файлов указать пользователя и группу которым они будут принадлежать. Так же возможно выполнить перезапуск сервиса после обновления сертификатов, для этого необходимо добавить ключ `service` с опциональными параметрами `name` и `reload`.

```yaml
salt_pki:
  issue:
    myservice:
      service:
        # необходимо если имя сервиса отличается от названия ветки,
        # в данном примере ветка 'myservice', а сервис 'my_service'
        name: my_service
        # использовать reload вместо restart, необходима поддержка со стороны самого сервиса
        reload: True
      key:
        name: myservice.key
        user: myuser
        group: mygroup
      cert:
        name: myservice.key
        user: myuser
        group: mygroup
```

В качестве альтернативы любая формула может иметь, собственныые, независимые от `pki.issue` стейты для выпуска сертификатов.