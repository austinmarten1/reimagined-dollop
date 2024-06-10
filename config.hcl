#Example

ui = true
cluster_addr = "http://127.0.0.1:8201"
api_addr = "http://127.0.0.1:8200"
disable_mlock = true

listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = true
}
storage "file" {
  path = "/mnt/data/openbao"
}
