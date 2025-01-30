# получаем id образа ubuntu 24.04
data "yandex_compute_image" "ubuntu2404" {
  family = "ubuntu-2404-lts-oslogin"
}

# получаем id дефолтной network
data "yandex_vpc_network" "default" {
  name = "default"
}

# создаем подсеть
resource "yandex_vpc_subnet" "subnet01" {
  name           = "subnet01"
  network_id     = data.yandex_vpc_network.default.network_id
  v4_cidr_blocks = ["10.16.0.0/24"]
}

# создаем инстансы под backend
resource "yandex_compute_instance" "backend" {
  count    = var.backend_size
  name     = "${var.backend_name}${count.index + 1}"
  hostname = "${var.backend_name}${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      name     = "boot-disk-${var.backend_name}${count.index + 1}"
      image_id = data.yandex_compute_image.ubuntu2404.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}


# создаем инстансы под frontend
resource "yandex_compute_instance" "frontend" {
  count    = var.frontend_size
  name     = "${var.frontend_name}${count.index + 1}"
  hostname = "${var.frontend_name}${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      name     = "boot-disk-${var.frontend_name}${count.index + 1}"
      image_id = data.yandex_compute_image.ubuntu2404.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# создаем инстанс под consule
resource "yandex_compute_instance" "consul" {
  name     = "consul"
  hostname = "consul"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      name     = "boot-disk-consul"
      image_id = data.yandex_compute_image.ubuntu2404.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# создаем inventory файл для Ansible
resource "local_file" "inventory" {
  filename        = "./hosts"
  file_permission = "0644"
  content         = <<EOT
[consul]
${yandex_compute_instance.consul.hostname} ansible_host=${yandex_compute_instance.consul.network_interface.0.nat_ip_address} ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[backend]
%{for vm in yandex_compute_instance.backend.*~}
${vm.hostname} ansible_host=${vm.network_interface.0.nat_ip_address} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{endfor~}

[frontend]
%{for vm in yandex_compute_instance.frontend.*~}
${vm.hostname} ansible_host=${vm.network_interface.0.nat_ip_address} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{endfor~}

EOT
}

# создаем Ansible playbook
resource "local_file" "playbook_yml" {
  filename        = "./playbook.yml"
  file_permission = "0644"
  content = templatefile("playbook.tmpl.yml", {
    remote_user  = var.system_user,
    backend_name = var.backend_name,
    backend_size = var.backend_size,
    backend      = yandex_compute_instance.backend[*],
    frontend     = yandex_compute_instance.frontend[*],
    consul       = yandex_compute_instance.consul
  })
}

