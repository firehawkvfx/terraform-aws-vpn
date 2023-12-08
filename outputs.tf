output "instance_name" {
  value = local.instance_name
}
output "private_route_table_ids" {
  value = local.private_route_table_ids
}
output "public_route_table_ids" {
  value = local.public_route_table_ids
}
output "public_ip" {
  value = length(aws_instance.neb_lighthouse) > 0 ? aws_instance.neb_lighthouse[0].public_ip : null
}
output "private_ip" {
  value = length(aws_instance.neb_lighthouse) > 0 ? aws_instance.neb_lighthouse[0].private_ip : null
}