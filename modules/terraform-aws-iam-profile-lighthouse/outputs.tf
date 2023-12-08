output "instance_role_arn" {
  value = aws_iam_role.instance_role.arn
  depends_on = [
    aws_iam_policy_attachment.ssm_managed_instance_core,
    module.iam_policies_vpn
  ]
}
output "instance_profile_arn" {
  value = aws_iam_instance_profile.instance_profile.arn
  depends_on = [
    aws_iam_policy_attachment.ssm_managed_instance_core,
    module.iam_policies_vpn
  ]
}
output "instance_role_name" {
  value = aws_iam_role.instance_role.name
  depends_on = [
    aws_iam_policy_attachment.ssm_managed_instance_core,
    module.iam_policies_vpn
  ]
}
output "instance_profile_name" {
  value = aws_iam_role.instance_role.name
  depends_on = [
    aws_iam_policy_attachment.ssm_managed_instance_core,
    module.iam_policies_vpn
  ]
}