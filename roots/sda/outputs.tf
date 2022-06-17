output "db" {
  # Access the password variable that is under db via the terraform map of data
  value = nonsensitive(data.sops_file.demo-secret.data["adminPassword"])
}
