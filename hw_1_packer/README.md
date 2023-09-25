# Использование packer для облака yandex


# 1.  Устанавливаем yandex облако 

https://cloud.yandex.ru/docs/cli/operations/install-cli

```
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
. ~/.bashrc
```

# 2. Устанавливаем packer


https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli#precompiled-binaries

```
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update&&sudo apt install packer
packer --version
```

> Устанавливаем plugin packer для yandex облака. Создаем файл config.pkr.hcl

```
packer {
  required_plugins {
    yandex = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/yandex"
    }
  }
}
```

> Подключаем config.pkr.hcl

```
packer init config.pkr.hcl
```

# 3. Иницилизируем yandex облако

> Ссылка для получения token https://oauth.yandex.ru/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb

```
yc init

#список id
yc config list
```

# 4. Создаем сервисную учётную запись и файл ключа

> Создаем сервисную учётную запись "packer" и выдаём права

```
#show id - yc config list
yc iam service-account create --name packer --folder-id "id_folder"
#show id service account - yc iam service-account list
yc resource-manager folder add-access-binding --id "id_folder" --role editor --service-account-id "service_account_id"
```

> создаём ключ

```
yc iam key create --service-account-id "service_account_id" --output key.json
```

# 5. Создаем файлы для создания образа

> Файл template.json - создание образа с использованием переменных среды и файла "service_account_key_file". Прописываем в файле template.json "folder_id" и 
> "service_account_key_file".

> "folder_id" задаётся через переменную среды "YC_FOLDER" зададим ее

```
export YC_FOLDER="folder_id"
```

> Создаём образ


```
packer build json/template.json
```

> Файл template2.json - создание образа с использованием файла переменных variables.auto.json

> Создаем variables.auto.json

```
{
  "folder_id": "b1g2v4unaic02432dg5d",
  "service_account_key_file": "./key.json"
}
```

> Создаём файл template2.json, где прописываем 

```
"folder_id": "{{user `folder_id`}}",
"service_account_key_file": "{{user `service_account_key_file`}}"
```

> Создаём образ, указывая дополнительно файл с переменными.

```
packer build -var-file=json/variables.auto.json json/template2.json
```

# 7. Создание виртуальной машины с помощью create_vm.sh

> Узнаем "subnet_id" и "zone" в yacloud

```
yc vpc subnet list
yc compute zone list
```

> Введем "subnet_id" и "zone" в "create_vm.sh"

> Создаем виртуальную машину запустив create_vm.sh с параметром id_image ( yc compute image list)

```
./create_vm.sh b1g2v4unaic02432dg5d
```

> в create_vm.sh указываем ssh ключ, через метаданные

```
 --metadata ssh-keys="ubuntu:$(cat ~/.ssh/id_rsa_testya.pub)"
```

> Если указать стандартно --ssh-key ~/.ssh/id_rsa_testya.pub, то будет создан пользователь yc-user и ключ пропишется в его профиль,
> а у нас используется пользователь ubuntu.

> Посмотреть список виртуальных машин, посмотреть метаданные виртуальной машины для проверки ssh ключа.

```
yc compute instance list
yc compute instance get --full <имя_ВМ>
```

> Остановим и удалим виртуальную машину. 

```
yc compute instance stop --id ef33nei975gnnjblkd8r
yc compute instance delete --id ef33nei975gnnjblkd8r
```

> Удаление через name

```
yc compute instance stop --name "vm_name"
```

# 7. Удаление образов

> Удаляем созданные образы:

```
yc compute image list
yc compute image delete --id "id_image"
```