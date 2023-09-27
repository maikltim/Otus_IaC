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