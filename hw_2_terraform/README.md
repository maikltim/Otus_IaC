# Домашнее задание к занятию “Terraform как инструмент для декларативного описания инфраструктуры”
 
 # Подготовка

> Настройка Yandex.Cloud

> Для выполнения ДЗ вам понадобится доступ к Yandex.Cloud (далее YC).

> Допускается использование и других облачных провайдеров, но все инструкции в данном документе будет приведены для YC.

> Так же в YC рекомендуется создать отдельный каталог для размещения ресурсов, созданных при выполнении ДЗ.

> Для создания каталога откройте веб-консоль управления YC https://console.cloud.yandex.ru/

> Далее в верхнем правом углу откройте список привязанных к вашей учетной записи облачных ресурсов и кликните на тот ресурс, в которым вы хотите создать
> дополнительных каталог - в данном примере это cloud-sablinigor2015:

> На открывшейся странице кликните на “+ Создать каталог”

> Заполните параметры нового каталога и кликните на кнопку “Создать”

> После создания каталога вернитесь на страницу https://console.cloud.yandex.ru/cloud?section=overview

> И запомните ID каталога - оно понадобится вам при работе с манифестами терраформа. ID указан в таблице со списком каталогов в столбце Идентификатор

> Кроме ID каталога вам нужно запомнить и Идентификатор Облака - он находится в блоке “Обзор” в строке “Идентификатор”. Его тоже нужно будет указывать в 
> манифестах терраформа.

# Цель работы 

> Подготовить отказоустойчивую облачную инфраструктуру для последующей установки Wordpress.

> Создание манифестов терраформа

> Прежде всего создайте репозиторий в одном из облачных сервисов (Gitlab, Github, к примеру) и склонируйте его на вашу рабочую станцию.

```
mkdir hw_2_terraform
```

> Дополнительно создадим файл .gitignore со следующим содержимым

```
# Created by https://www.toptal.com/developers/gitignore/api/terraform
# Edit at https://www.toptal.com/developers/gitignore?templates=terraform

### Terraform ###
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log

# Exclude all .tfvars files, which are likely to contain sentitive data, such as
# password, private keys, and other secrets. These should not be part of version
# control as they are data points which are potentially sensitive and subject
# to change depending on the environment.
#
*.tfvars
*.auto.tfvars

# Ignore override files as they are usually used to override resources locally and so
# are not checked in
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Include override files you do wish to add to version control using negated pattern
# !example_override.tf

# Include tfplan files to ignore the plan output of command: terraform plan -out=tfplan
# example: *tfplan*

# Ignore CLI configuration files
.terraformrc
terraform.rc

# End of https://www.toptal.com/developers/gitignore/api/terraform
```

> Файлы, содержащие значения переменных не будут отправлены в удаленный репозиторий. Это делается для того, чтобы случайно не передать туда пароли и другую 
> секретную информацию, которая может содержаться в этих файлах.

```
...
*.tfvars
*.auto.tfvars
...
```

> Теперь давайте перейдем в каталог hw_2_terraform и создадим необходимые манифесты.


```
cd hw_2_terraform
```

# Провайдер


> Начнем с манифеста, который будет описывать к какому облачному провайдеру мы планируем обратиться.

> Создадим файл provider.tf со следующим содержимым:


```
provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud
  folder_id = var.yc_folder
}

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}
```

> Здесь мы указываем, что провайдер у нас Yandex.Cloud

```
provider "yandex" {
...
```

> И передаем необходимые переменные для использования данного провайдера, токен, ID облака и ID каталога. Файл со значениями этих переменных мы создадим позже.

> Далее, в этом же файле, мы указываем дополнительный блок, который будет использовать терраформ:

```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
```
> Теперь нам надо создать файл variables.tf, в которым мы опишем какие переменные мы будем использовать в наших манифестах:


```
variable "yc_cloud" {
  type = string
  description = "Yandex Cloud ID"
}

variable "yc_folder" {
  type = string
  description = "Yandex Cloud folder"
}

variable "yc_token" {
  type = string
  description = "Yandex Cloud OAuth token"
}

variable "db_password" {
  description = "MySQL user pasword"
}
```

> А их значения мы укажем в файле wp.auto.tfvars
> Содержимое этого файла следующее (!!! Указанные ниже значения приведены для примера !!!):


```
yc_cloud  = "b1gf5768rgabjbptan7a"
yc_folder = "b1gb8haadbndninaj928"
yc_token = "jlkdsflgjoisgoskljgs"
db_password = "password"
```

> Напомню, что эти ID облака и каталога вы запомнили/записали при создании каталога в YC.

> Чтобы узнать ваш токен, выполните команду

```
yc config list
```

> Итак, на текущий момент структура вашего репозитория должна быть следующей:
```
.
└── hw_2_terraform
    ├── provider.tf
    ├── variables.tf
    └── wp.auto.tfvars
```
> Теперь мы можем переходить к созданию манифестов для наших ресурсов.

# Виртуальные сети

> Сначала создадим виртуальную сеть.

> Для этого мы будем использовать файл network.tf со следующим содержимым:

```
resource "yandex_vpc_network" "wp-network" {
  name = "wp-network"
}

resource "yandex_vpc_subnet" "wp-subnet-a" {
  name = "wp-subnet-a"
  v4_cidr_blocks = ["10.2.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.wp-network.id
}

resource "yandex_vpc_subnet" "wp-subnet-b" {
  name = "wp-subnet-b"
  v4_cidr_blocks = ["10.3.0.0/16"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.wp-network.id
}

resource "yandex_vpc_subnet" "wp-subnet-c" {
  name = "wp-subnet-c"
  v4_cidr_blocks = ["10.4.0.0/16"]
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.wp-network.id
}
```

> Обратите внимание, что здесь мы создаем ресурс типа yandex_vpc_network и три ресурса с подсетями yandex_vpc_subnet, которые будут располагаться в разных зонах 
> (помним про отказоустойчивость!).


> Соответственно, в ресурсе yandex_vpc_subnet мы указываем блок IP-адресов, зону, где будет расположена данная подсеть и ссылку на саму виртуальную сеть.

> Давайте проверим как работает данный манифест, выполним команду:

```
terraform apply --auto-approve
```

> Флаг --auto-approve мы используем, чтобы не тратить лишнее время на подтверждение запроса о применении манифеста.

> Если в манифесте мы не допустили ошибок, то после исполнения команды, последним сообщением мы увидим:

```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

> Действительно, мы создали четыре новых ресурса - одну виртуальную сеть и три ее подсети.

# Виртуальные машины

> Следующая задача - манифесты для хостов, где будет разворачиваться WordPress.

> Создадим файл wp-app.tf со следующим содержимым: 

```
resource "yandex_compute_instance" "wp-app-1" {
  name = "wp-app-1"
  zone = "ru-central1-a"

  resources {
    cores = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.lamp.id
    }
  }

  network_interface {
    # Указан id подсети default-ru-central1-a
    subnet_id = yandex_vpc_subnet.wp-subnet-a.id
    nat       = true 
  }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
}

resource "yandex_compute_instance" "wp-app-2" {
  name = "wp-app-2"
  zone = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }
   boot_disk {
     initialize_params {
       image_id = data.yandex_compute_image.lemp.id
    }
}
    network_interface {
      subnet_id = yandex_vpc_subnet.wp-subnet-b.id
      nat       = true
    }

   metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

}
```

> Снова запустим команду применения манифестов и убедимся, что виртуальные машины созданы успешно:

```
terraform apply --auto-approve
...
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

# Балансировщик трафика

> Итак, виртуальные машины у нас есть, теперь мы можем создать балансировщик, который будет перенаправлять на них пользовательский трафик.

> Создадим манифест lb.tf со следующим содержимым:

```
resource "yandex_lb_target_group" "wp_tg" {
  name      = "wp-target-group"

  target {
    subnet_id = yandex_vpc_subnet.wp-subnet-a.id
    address   = yandex_compute_instance.wp-app-1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.wp-subnet-b.id
    address   = yandex_compute_instance.wp-app-2.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "wp_lb" {
  name = "wp-network-load-balancer"

  listener {
    name = "wp-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.wp_tg.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
```

> В данном манифесте мы, во-первых, создаем группу хостов, куда будем направлять трафик, при помощи ресурса yandex_lb_target_group. В нем мы ссылаемся на 
> IP-адреса созданных ранее виртуальных машин.


> Далее мы создаем сам балансировщик при помощи ресурса yandex_lb_network_load_balancer. В блоке listener мы указываем порт, который будет слушать балансировщик. 
> А в блоке attached_target_group указывается ссылка на группу хостов yandex_lb_target_group.

> Запустим команду применения манифестов и убедимся, что виртуальные машины созданы успешно:

```
terraform apply --auto-approve
...
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

> В данном случае, два новых ресурса - это сам балансировщик и группа хостов, на которые он направляет трафик.

# База данных

> Предполагается, что в качестве бекэнда для WordPress-а мы будем использовать MySQL.

> Воспользуемся для этой цели возможностью создать в YC облачный кластер MySQL и опишем для этого соответствующий манифест.
> Назовем его db.tf
> Содержимое манифеста будет:


```
locals {
  dbuser = tolist(yandex_mdb_mysql_cluster.wp_mysql.user.*.name)[0]
  dbpassword = tolist(yandex_mdb_mysql_cluster.wp_mysql.user.*.password)[0]
  dbhosts = yandex_mdb_mysql_cluster.wp_mysql.host.*.fqdn
  dbname = tolist(yandex_mdb_mysql_cluster.wp_mysql.database.*.name)[0]
}

resource "yandex_mdb_mysql_cluster" "wp_mysql" {
  name        = "wp-mysql"
  folder_id   = var.yc_folder
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.wp-network.id
  version     = "8.0"

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id       = "network-ssd"
    disk_size          = 16
  }

  database {
    name  = "db"
  }

  user {
    name     = "user"
    password = var.db_password
    authentication_plugin = "MYSQL_NATIVE_PASSWORD"
    permission {
      database_name = "db"
      roles         = ["ALL"]
    }
  }

  host {
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.wp-subnet-b.id
    assign_public_ip = true
  }
  host {
    zone      = "ru-central1-c"
    subnet_id = yandex_vpc_subnet.wp-subnet-c.id
    assign_public_ip = true
  }
}
```

> Кластер баз данных мы создаем при помощи ресурса yandex_mdb_mysql_cluster.

> Из основного в нем стоит обратить внимание на version, где задается версия MySQL.

> В блоках database и user мы задаем имя базы и имя с паролем для пользователя базы, соответственно.
> В блоках host указываются подсети, где будут размещены узлы кластера.

> Итак, запустим команду применения манифестов и убедимся, что кластер баз данных создан успешно. На этот раз придется подождать около десяти минут, создание 
> кластера - дело не быстрое.

```
terraform apply --auto-approve
...
yandex_mdb_mysql_cluster.wp_mysql: Creation complete after 8m43s [id=t10gqolkr9pd30thkklro]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

# Output-переменные

> И в завершении давайте создадим файл output.tf, где укажем вывод некоторой информации, которая может нам пригодится.

> Содержимое данного манифеста:

```
output "load_balancer_public_ip" {
  description = "Public IP address of load balancer"
  value = yandex_lb_network_load_balancer.wp_lb.listener.*.external_address_spec[0].*.address
}

output "database_host_fqdn" {
  description = "DB hostname"
  value = local.dbhosts
}
```

> Как нетрудно заметить, вы запрашиваем вывод IP балансировщика и dns-имена баз данных.

> Мы можем запустить команду terraform apply еще раз и, хотя в этот раз никаких новых ресурсов мы не создали, но мы увидим вывод запрошенной информации:


```
terraform apply --auto-approve
...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

database_host_fqdn = tolist([
  "rc1b-p3k4kmf75ftq00lo.mdb.yandexcloud.net",
  "rc1c-r0kidk4l1j8ns756.mdb.yandexcloud.net",
])
load_balancer_public_ip = tolist([
  "84.252.131.111",
])
```
# Удаление ресурсов

```
terraform destroy --auto-approve
...

Destroy complete! Resources: 9 destroyed.
```