// ============================================================================
// VPC Outputs
// ============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.private_vpc.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.subnets[var.private_subnet_name].id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.subnets[var.public_subnet_name].id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.private_sg.id
}

// ============================================================================
// IAM Outputs
// ============================================================================

output "instance_profile" {
  description = "Instance profile name"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.ec2_admin_role.name
}

// ============================================================================
// Standard EC2 Instance Outputs
// ============================================================================

//output "ec2_instance_id" {
//  description = "Standard EC2 instance ID"
//  value       = aws_instance.private_ec2.id
//}

// ============================================================================
// Puppet Master and Agent Outputs
// ============================================================================

output "puppet_master_id" {
  description = "Puppet Master instance ID"
  value       = var.enable_puppet ? aws_instance.puppet_master[0].id : "N/A (Puppet disabled)"
}

output "puppet_master_private_ip" {
  description = "Puppet Master private IP"
  value       = var.enable_puppet ? aws_instance.puppet_master[0].private_ip : "N/A"
}

output "puppet_master_public_ip" {
  description = "Puppet Master public IP"
  value       = var.enable_puppet ? aws_instance.puppet_master[0].public_ip : "N/A"
}

output "puppet_agent_ids" {
  description = "Puppet Agent instance IDs"
  value       = var.enable_puppet ? aws_instance.puppet_agent[*].id : []
}

output "puppet_agent_private_ips" {
  description = "Puppet Agent private IPs"
  value       = var.enable_puppet ? aws_instance.puppet_agent[*].private_ip : []
}

output "puppet_agent_public_ips" {
  description = "Puppet Agent public IPs"
  value       = var.enable_puppet ? aws_instance.puppet_agent[*].public_ip : []
}

output "puppet_master_ssh_command" {
  description = "SSH command to connect to Puppet Master"
  value = var.enable_puppet ? format(
    "ssh -i your-key.pem ec2-user@%s",
    aws_instance.puppet_master[0].public_ip
  ) : "N/A"
}

output "puppet_agent_ssh_commands" {
  description = "SSH commands to connect to Puppet Agents"
  value = var.enable_puppet ? [
    for i, agent in aws_instance.puppet_agent : format(
      "ssh -i your-key.pem ec2-user@%s # Agent %d",
      agent.public_ip,
      i + 1
    )
  ] : []
}


locals {
  puppet_setup_notes = <<-EON
    Puppet Master and Agents are deployed.
    
    INITIAL SETUP (Manual):
    1. SSH to Puppet Master and run: sudo puppet cert list
    2. Review pending certificate requests from agents
    3. Sign agent certificates: sudo puppet cert sign agent-name
    
    After signing, agents will pull manifests and apply catalog.
    
    TEST CONNECTIVITY:
    1. SSH to Puppet Master: ${aws_instance.puppet_master[0].public_ip}
    2. Check agent cert status: sudo puppet cert list
    3. SSH to any agent and check:
       - sudo systemctl status puppet
       - tail -f /var/log/puppet-agent-init.log
       - ls -la /tmp/puppet_*.txt
    
    EXPECTED FILES ON AGENTS:
    - /tmp/puppet_test_file.txt (copied from master manifest)
    - /tmp/puppet_connectivity_test.txt (created by manifest)
    
    Check file contents:
    cat /tmp/puppet_test_file.txt
    cat /tmp/puppet_connectivity_test.txt
    "Puppet is disabled. Set enable_puppet = true in terraform.tfvars"
  EON
}


output "puppet_setup_notes" {
  description = "Notes for Puppet setup and testing"
  value       = var.enable_puppet ? local.puppet_setup_notes : "N/A"
}