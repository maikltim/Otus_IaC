# Тестирование инфраструктуры


# 1. Установим go

https://go.dev/doc/install



```
wget https://go.dev/dl/go1.21.1.linux-amd64.tar.gz
go version
sudo rm -rvf /usr/local/go && sudo tar -C /usr/local -xzf go1.21.1.linux-amd64.tar.gz
```

> Проверим, что в /etc/profile

> Есть строка с переменными среды go

```
export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin
```

```
. /etc/profile
go version
```

# 2. Пишем тесты

> Создадим каталог stage в yandex облаке

> Настроим для новой папки profile

```
yc init
yc config list
```

> Сначала изменим вывод переменной load_balancer_public_ip на следующий:

```
output "load_balancer_public_ip" {
  description = "Public IP address of load balancer"
  value = tolist(tolist(yandex_lb_network_load_balancer.wp_lb.listener).0.external_address_spec).0.address
}
```

> И добавим еще одну переменную для определения IP одной из виртуальных машин

```
output "load_balancer_public_ip" {
  description = "Public IP address of load balancer"
  value = tolist(tolist(yandex_lb_network_load_balancer.wp_lb.listener).0.external_address_spec).0.address
}
```

> В итоге файл output.tf должен выглядеть так:

```
output "load_balancer_public_ip" {
 description = "Public IP address of load balancer"
 value = tolist(tolist(yandex_lb_network_load_balancer.wp_lb.listener).0.external_address_spec).0.address
}

output "database_host_fqdn" {
 description = "DB hostname"
 value = local.dbhosts
}

output "vm_linux_public_ip_address" {
 description = "Virtual machine IP"
 value = yandex_compute_instance.wp-app-1.network_interface[0].nat_ip_address
}
```

> .gitignore 

> Прежде чем мы приступим к написанию тестов дополним файл .gitignore блоком с исключениями для языка Go

```
# Created by https://www.toptal.com/developers/gitignore/api/go
# Edit at https://www.toptal.com/developers/gitignore?templates=go

### Go ###
# Binaries for programs and plugins
*.exe
*.exe~
*.dll
*.so
*.dylib

# Test binary, built with `go test -c`
*.test

# Output of the go coverage tool, specifically when used with LiteIDE
*.out

# Dependency directories (remove the comment below to include it)
# vendor/

### Go Patch ###
vendor
Godeps

# End of https://www.toptal.com/developers/gitignore/api/go
```

> Terratest
> Инициализация проекта
> Создадим в каталоге terraform подкаталог test.
> В test создадим файл end2end_test.go со следующим содержимым:


```
package test

import (
    "testing"
)

func TestEndToEndDeploymentScenario(t *testing.T) {
}
```

> Выполним команду:

```
go mod init test
```

> в каталоге появился файл go.mod

```
module test

go 1.21.1
```

> Дополним end2end_test.go необходимыми командами

```
package test

import (
	"flag"
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

var folder = flag.String("folder", "", "Folder ID in Yandex.Cloud")

func TestEndToEndDeploymentScenario(t *testing.T) {

	terraformOptions := &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"yc_folder": *folder,
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	fmt.Println("Finish infra.....")

	time.Sleep(30 * time.Second)

	fmt.Println("Destroy infra.....")
}
```

> Прежде чем запустить тест, выполним команду, скачивающую необходимые зависимости

```
go mod vendor
go get github.com/gruntwork-io/terratest/modules/terraform
go mod vendor
```

> проверить, чтобы все скаченные файлы не тянулись в репозитарий (.gitignore)

```
vendor
```

> Запускаем программу

> Запустим тест указав в параметрах -timeout, -folder, -v -поддробный вывод, ./ - запуск из текущей директории.


```
go test -v ./ -timeout 30m -folder 'b1gakustnqk6883rv88c'
```

```
--- PASS: TestEndToEndDeploymentScenario (686.23s)
PASS
ok      test    686.233s
```

> Управление стадиями тестирования

> Придадим файлу end2end_test.go следующий вид, чтобы не происходило каждый раз пересоздание инфраструктуры.

```
package test

import (
	"fmt"
	"flag"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

var folder = flag.String("folder", "", "Folder ID in Yandex.Cloud")

func TestEndToEndDeploymentScenario(t *testing.T) {
    fixtureFolder := "../"

    test_structure.RunTestStage(t, "setup", func() {
		terraformOptions := &terraform.Options{
			TerraformDir: fixtureFolder,

			Vars: map[string]interface{}{
			"yc_folder":    *folder,
		    },
	    }

		test_structure.SaveTerraformOptions(t, fixtureFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
	    fmt.Println("Run some tests...")

    })

	test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, fixtureFolder)
		terraform.Destroy(t, terraformOptions)
	})
}
```

> Что изменилось - теперь разные стадии прохождения процесса тестирования (создание инфраструктуры, собственно тесты, удаление инфраструктуры) мы “обернули” в
> специальную функцию test_structure.RunTestStage. Среди ее параметров можно увидеть имя стадии (setup/validate.teardown) и неименованную функцию, в которой и 
> происходит необходимые действия.

> Плюс, слегка изменился блок imports - добавлена строка test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

> Переименуем или удалим go.mod Еще раз выполним команду


```
go mod vendor
go get github.com/gruntwork-io/terratest/modules/test-structure
go mod vendor
```

> И запустим тест

```
go test -v ./ -timeout 30m -folder 'b1gakustnqk6883rv88c'
```

> Итого, упоминаются несколько переменных окружения, имя которых состоит из префикса “SKIP_” и имени стадии. И именно при помощи этих переменных мы можем 
> управлять тем, будет ли выполняться та или иная стадия, или нет.

 > Проверим так ли это. Допустим мы хотим, чтобы при очередном запуске выполнилась только стадия setup (создания инфраструктуры).

```
TestEndToEndDeploymentScenario 2023-10-04T12:09:55+03:00 test_structure.go:27: The 'SKIP_setup' environment variable is not set, so executing stage 'setup'.
TestEndToEndDeploymentScenario 2023-10-04T12:09:55+03:00 save_test_data.go:196: Storing test data in ../.test-data/TerraformOptions.json
...............................
TestEndToEndDeploymentScenario 2023-10-04T12:17:05+03:00 test_structure.go:27: The 'SKIP_validate' environment variable is not set, so executing stage 'validate'.
Run some tests...
TestEndToEndDeploymentScenario 2023-10-04T12:17:05+03:00 test_structure.go:27: The 'SKIP_teardown' environment variable is not set, so executing stage 'teardown'.
```

> Для этого мы определим две переменные окружения:

```
export SKIP_validate=true
export SKIP_teardown=true
```

> И снова запустим тест:

```
go test -v ./ -timeout 30m -folder 'b1gakustnqk6883rv88c'
```

```
TestEndToEndDeploymentScenario 2023-10-04T12:38:28+03:00 test_structure.go:30: The 'SKIP_validate' environment variable is set, so skipping stage 'validate'.
TestEndToEndDeploymentScenario 2023-10-04T12:38:28+03:00 test_structure.go:30: The 'SKIP_teardown' environment variable is set, so skipping stage 'teardown'.
--- PASS: TestEndToEndDeploymentScenario (430.69s)
PASS
ok      test    430.707s
```

> На этот раз отработала только стадия создания инфраструктуры. Стадии непосредственно тестирования и удаления инфраструктуры не запустились.

> И, если при следующих итерациях, мы хотим чтобы запускалась только стадия validate, то мы сделаем следующее:

```
export SKIP_setup=true
unset SKIP_validate
```
> И проверим, получилось ли то, что нам нужно:

```
=== RUN   TestEndToEndDeploymentScenario
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 test_structure.go:30: The 'SKIP_setup' environment variable is set, so skipping stage 'setup'.
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 test_structure.go:27: The 'SKIP_validate' environment variable is not set, so executing stage 'validate'.
Run some tests...
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 test_structure.go:30: The 'SKIP_teardown' environment variable is set, so skipping stage 'teardown'.
--- PASS: TestEndToEndDeploymentScenario (0.00s)
PASS
ok      test    0.013s
```


# Действительно пишем тесты

> Для проверки наличия IP балансировщика добавим в стадию validate после строчки

> fmt.Println("Run some tests...")

> следующий блок

```
    terraformOptions := test_structure.LoadTerraformOptions(t, fixtureFolder)

        // test load balancer ip existing
	    loadbalancerIPAddress := terraform.Output(t, terraformOptions, "load_balancer_public_ip")

	    if loadbalancerIPAddress == "" {
			t.Fatal("Cannot retrieve the public IP address value for the load balancer.")
		}
```
> Запустим тест

```
=== RUN   TestEndToEndDeploymentScenario
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 test_structure.go:30: The 'SKIP_setup' environment variable is set, so skipping stage 'setup'.
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 test_structure.go:27: The 'SKIP_validate' environment variable is not set, so executing stage 'validate'.
Run some tests...
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 save_test_data.go:229: Loading test data from ../.test-data/TerraformOptions.json
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 retry.go:91: terraform [output -no-color -json load_balancer_public_ip]
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 logger.go:66: Running command terraform with args [output -no-color -json load_balancer_public_ip]
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 logger.go:66: "158.160.123.150"
TestEndToEndDeploymentScenario 2023-10-04T12:39:31+03:00 test_structure.go:30: The 'SKIP_teardown' environment variable is set, so skipping stage 'teardown'.
--- PASS: TestEndToEndDeploymentScenario (0.52s)
PASS
ok      test    0.549s
```

> Обратите внимание, что после Run some tests... появились строки, описывающие прохождение проверки на наличие IP балансировщика.

> Итак, первый тест мы сделали, давайте перейдем к более сложному тесту - проверки возможности подключения по ssh.

> И раз мы предполагаем подключение к виртуальной машине, то terratest-у как-то надо передать приватный ключ, при помощи которого он и будет пытаться выполнить 
> подключение.

> Для этого мы добавим возможность указание еще одного флага - пути к приватному ключу.

> После определения переменной

```
var folder = ...
```

> Добавим еще одну

```
var sshKeyPath = flag.String("ssh-key-pass", "", "Private ssh key for access to virtual machines")
```

> Здесь мы предполагаем, что при запуске тестов во флаге ssh-key-pass будет передан путь к приватному ключу.

> И, после блока

```
  if loadbalancerIPAddress == "" {
			t.Fatal("Cannot retrieve the public IP address value for the load balancer.")
		}
```

> добавим достаточно большой блок

```
// test ssh connect
		vmLinuxPublicIPAddress := terraform.Output(t, terraformOptions, "vm_linux_public_ip_address")

		key, err := ioutil.ReadFile(*sshKeyPath)
		if err != nil {
			t.Fatalf("Unable to read private key: %v", err)
		}

		signer, err := ssh.ParsePrivateKey(key)
		if err != nil {
			t.Fatalf("Unable to parse private key: %v", err)
		}

		sshConfig := &ssh.ClientConfig{
			User: "ubuntu",
			Auth: []ssh.AuthMethod{
				ssh.PublicKeys(signer),
			},
			HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		}

		sshConnection, err := ssh.Dial("tcp", fmt.Sprintf("%s:22", vmLinuxPublicIPAddress), sshConfig)
		if err != nil {
			t.Fatalf("Cannot establish SSH connection to vm-linux public IP address: %v", err)
		}

		defer sshConnection.Close()
        
		sshSession, err := sshConnection.NewSession()
		if err != nil {
			t.Fatalf("Cannot create SSH session to vm-linux public IP address: %v", err)
		}

		defer sshSession.Close()
        
		err = sshSession.Run(fmt.Sprintf("ping -c 1 8.8.8.8"))
		if err != nil {
			t.Fatalf("Cannot ping 8.8.8.8: %v", err)
		}
```

> Так как мы добавили новую библиотеку, то не забываем выполнить

```
go mod vendor
```

> Запускаем тест, и обратите внимание на дополнительный флаг - -ssh-key-pass

```
go test -v ./ -timeout 30m -folder 'b1gakustnqk6883rv88c' -ssh-key-pass '/home/maikltim/.ssh/id_rsa.pub'
```

> Результат:


```
=== RUN   TestEndToEndDeploymentScenario
TestEndToEndDeploymentScenario 2023-10-04T12:50:31+03:00 test_structure.go:30: The 'SKIP_setup' environment variable is set, so skipping stage 'setup'.
TestEndToEndDeploymentScenario 2023-10-04T12:50:31+03:00 test_structure.go:27: The 'SKIP_validate' environment variable is not set, so executing stage 'validate'.
Run some tests...
TestEndToEndDeploymentScenario 2023-10-04T12:50:31+03:00 save_test_data.go:229: Loading test data from ../.test-data/TerraformOptions.json
TestEndToEndDeploymentScenario 2023-10-04T12:50:31+03:00 retry.go:91: terraform [output -no-color -json load_balancer_public_ip]
TestEndToEndDeploymentScenario 2023-10-04T12:50:31+03:00 test_structure.go:30: The 'SKIP_teardown' environment variable is set, so skipping stage 'teardown'.
--- PASS: TestEndToEndDeploymentScenario (2.17s)
PASS
ok      test    2.202s
```

# ЗАДАНИЕ СО ЗВЕЗДОЧКОЙ

> Для проверки mysql соединения с серверами кластера с локальной машины, необхоимо скачать ssl корневой сертификат yandex облака ( так как снаружи из 
> интернета разрешены только безопасные ssl подключения)


```
mkdir -p ~/.mysql && \
wget "https://storage.yandexcloud.net/cloud-certs/CA.pem" \
     --output-document ~/.mysql/root.crt && \
chmod 0600 ~/.mysql/root.crt
```
> Нам потребуется подключить библиотеки mysql, crypto добавим в блок Import

```
import (
	"crypto/tls"
	"crypto/x509"
	"database/sql"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"testing"

	"github.com/go-sql-driver/mysql"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"golang.org/x/crypto/ssh"
)
```

```
go mod vendor
```

> Так как будем проверять все узлы кластера необходимо преобразовать в файле output.tf 
> output "database_host_fqdn" в список


```
output "database_host_fqdn" {
  description = "DB hostname"
  value = tolist(local.dbhosts)
}
```
> Добавим блок тестирования подключения к серверам Mysql кластера

```
// test connect to mysql server
		databaseHostFQDNs := terraform.OutputList(t, terraformOptions, "database_host_fqdn")

		const (
			port   = 3306
			user   = "user"
			dbname = "db"
		)

		password := os.Getenv("MYSQL_PASSWORD")
		if password == "" {
			t.Fatal("MYSQL_PASSWORD переменная среды не установлена.")
		}

		rootCertPool := x509.NewCertPool()
		pem, err := ioutil.ReadFile("/home/tolik/.mysql/root.crt")
		if err != nil {
			log.Fatalf("Ошибка чтения корневого сертификата: %v", err)
		}

		if ok := rootCertPool.AppendCertsFromPEM(pem); !ok {
			log.Fatal("Не удалось добавить PEM-сертификат в пул корневых сертификатов.")
		}

		mysql.RegisterTLSConfig("custom", &tls.Config{
			RootCAs: rootCertPool,
		})

		// Перебираем каждый сервер
		for _, host := range databaseHostFQDNs {
			mysqlInfo := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?tls=custom",
				user, password, host, port, dbname)
			conn, err := sql.Open("mysql", mysqlInfo)
			if err != nil {
				log.Fatalf("Ошибка подключения к серверу %s: %v", host, err)
			}

			defer conn.Close()

			q, err := conn.Query("SELECT version()")
			if err != nil {
				log.Fatalf("Ошибка выполнения SQL-запроса на сервере %s: %v", host, err)
			}

			var result string

			for q.Next() {
				q.Scan(&result)
				fmt.Printf("Версия MySql на сервере %s: %s\n", host, result)
			}
		}
```

> Пароль задаётся, через переменную среды MYSQL_PASSWORD

```
export MYSQL_PASSWORD="PASS"
```

> Запустим тестирование:

```
go test -v ./ -timeout 30m -folder 'b1gakustnqk6883rv88c' -ssh-key-pass '/home/maikltim/.ssh/id_rsa.pub' 
```

> Вывод результата:

```
=== RUN   TestEndToEndDeploymentScenario
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 test_structure.go:30: The 'SKIP_setup' environment variable is set, so skipping stage 'setup'.
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 test_structure.go:27: The 'SKIP_validate' environment variable is not set, so executing stage 'validate'.
Run some tests...
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 save_test_data.go:229: Loading test data from ../.test-data/TerraformOptions.json
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 retry.go:91: terraform [output -no-color -json load_balancer_public_ip]
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 logger.go:66: Running command terraform with args [output -no-color -json load_balancer_public_ip]
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 logger.go:66: "158.160.62.204"
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 retry.go:91: terraform [output -no-color -json vm_linux_public_ip_address]
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 logger.go:66: Running command terraform with args [output -no-color -json vm_linux_public_ip_address]
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 logger.go:66: "158.160.124.170"
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 retry.go:91: terraform [output -no-color -json database_host_fqdn]
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 logger.go:66: Running command terraform with args [output -no-color -json database_host_fqdn]
TestEndToEndDeploymentScenario 2023-10-05T12:50:31+03:00 logger.go:66: ["rc1b-9fv1qpqa1n2vn87y.mdb.yandexcloud.net","rc1c-spqci4glj8ngrjg6.mdb.yandexcloud.net"]
Версия MySql на сервере rc1b-9fv1qpqa1n2vn87y.mdb.yandexcloud.net: 8.0.30-22
Версия MySql на сервере rc1c-spqci4glj8ngrjg6.mdb.yandexcloud.net: 8.0.30-22
TestEndToEndDeploymentScenario 2023-10-04T11:24:17+03:00 test_structure.go:30: The 'SKIP_teardown' environment variable is set, so skipping stage 'teardown'.
--- PASS: TestEndToEndDeploymentScenario (2.59s)
PASS
ok      test    2.625s
```

# 3. Финальное тестирование

> Сначала удалим нашу текущую инфраструктуру.

> Для этого удалим переменную окружения SKIP_teardown:

```
unset SKIP_teardown
```

> Снова запустим тесты и на этот раз после их выполнения будет проведено удаление инфраструктуры:


```
go test -v ./ -timeout 30m -folder 'b1gakustnqk6883rv88c' -ssh-key-pass '/home/maikltim/.ssh/id_rsa.pub' 
```

> Теперь удалим оставшуюся переменную окружения SKIP ( список должен быть пустым env)

```
 env | grep SKIP
 unset SKIP_setup
```

> И запустим полный цикл тестирования в выводов результатов в лог tg_test.log и на экран

```
go test -v ./ -timeout 30m -folder 'b1gakustnqk6883rv88c' -ssh-key-pass '/home/maikltim/.ssh/id_rsa.pub | tee tg_test.log'
```