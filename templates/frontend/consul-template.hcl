consul {
 address = "consul:8500"

 retry {
   enabled  = true
   attempts = 12
   backoff  = "250ms"
 }
}
template {
 source      = "/var/lib/consul-template/frontend-balancer.conf.ctmpl"
 destination = "/etc/nginx/sites-enabled/frontend-balancer.conf"
 perms       = 0600
 command = "service nginx reload"
}