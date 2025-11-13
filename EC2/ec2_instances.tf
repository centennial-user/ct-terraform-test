// Standard EC2 Instance
/*
resource "aws_instance" "private_ec2" {
  ami                    = data.aws_ssm_parameter.latest_ami.value
  instance_type          = var.instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  subnet_id              = aws_subnet.subnets[var.private_subnet_name].id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOF
    #!/bin/bash
    echo "Initializing EC2 with SSM Agent and Terraform" > /var/log/ssm-init.log
    yum update -y
    if ! systemctl status amazon-ssm-agent &>/dev/null; then
      yum install -y amazon-ssm-agent
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    fi
    yum install -y yum-utils unzip curl
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    yum -y install terraform
    terraform -version >> /var/log/ssm-init.log
    echo "Setup complete at $(date)" >> /var/log/ssm-init.log
  EOF

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-ec2" })
}
*/

// ============================================================================
// Puppet Master EC2 Instance
// ============================================================================

resource "aws_instance" "puppet_master" {
  count                  = var.enable_puppet ? 1 : 0
  ami                    = data.aws_ssm_parameter.latest_ami.value
  instance_type          = var.puppet_instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  subnet_id              = aws_subnet.subnets[var.public_subnet_name].id
  vpc_security_group_ids = [aws_security_group.puppet_sg[0].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    set -x
    exec > /var/log/puppet-master-init.log 2>&1

    # Update system
    yum update -y

    if ! systemctl status amazon-ssm-agent &>/dev/null; then
      yum install -y amazon-ssm-agent
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    fi

    # Set hostname for Puppet
    HOSTNAME="${var.name_prefix}-puppet-master"
    hostnamectl set-hostname $HOSTNAME
    echo "127.0.0.1 $HOSTNAME" >> /etc/hosts

    # Install Puppet Server
    yum install -y gcc ruby-devel
    yum install -y https://yum.puppetlabs.com/puppet8-release-1.0.0-10.el8.noarch.rpm
    yum install -y puppetserver

    # Create Puppet manifests directory
    mkdir -p /etc/puppetlabs/code/environments/production/manifests
    mkdir -p /etc/puppetlabs/code/environments/production/modules/testfile/files

    # Create a test file to be distributed
    cat > /etc/puppetlabs/code/environments/production/modules/testfile/files/test_message.txt <<'MANIFEST'
This is a test file copied by Puppet from Master to Agent at $(date)
Agent: $(hostname)
MANIFEST

    # Create Puppet manifest to distribute the file
    cat > /etc/puppetlabs/code/environments/production/manifests/site.pp <<'MANIFEST'
node default {
  class { 'testfile': }
}

class testfile {
  file { '/tmp/puppet_test_file.txt':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/testfile/test_message.txt',
    require => Class['testfile'],
  }

  # Create a connectivity test file
  file { '/tmp/puppet_connectivity_test.txt':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "Puppet Agent successfully applied catalog from master at \$(date)\n",
  }
}
MANIFEST

    # Configure Puppet server
    sed -i 's/-Xmx2g/-Xmx512m/g' /etc/sysconfig/puppetserver
    systemctl start puppetserver
    systemctl enable puppetserver

    # Wait for Puppet to start
    sleep 10

    # Show status
    systemctl status puppetserver || true
    echo "Puppet Master setup complete at $(date)"
  EOF
  )

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-puppet-master" })

  depends_on = [aws_security_group.puppet_sg]
}

// ============================================================================
// Puppet Agent EC2 Instances
// ============================================================================

resource "aws_instance" "puppet_agent" {
  count                  = var.enable_puppet ? var.puppet_agent_count : 0
  ami                    = data.aws_ssm_parameter.latest_ami.value
  instance_type          = var.puppet_instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  subnet_id              = aws_subnet.subnets[var.private_subnet_name].id
  vpc_security_group_ids = [aws_security_group.puppet_sg[0].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -x
    exec > /var/log/puppet-agent-init.log 2>&1

    # Update system
    yum update -y
    
    if ! systemctl status amazon-ssm-agent &>/dev/null; then
      yum install -y amazon-ssm-agent
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    fi
    
    # Set hostname for Puppet
    HOSTNAME="${var.name_prefix}-puppet-agent-${count.index + 1}"
    hostnamectl set-hostname $HOSTNAME
    echo "127.0.0.1 $HOSTNAME" >> /etc/hosts

    # Add Puppet Master to hosts file for DNS resolution
    echo "${aws_instance.puppet_master[0].private_ip} puppet puppet.local ${var.name_prefix}-puppet-master" >> /etc/hosts

    # Install Puppet Agent
    yum install -y gcc ruby-devel
    yum install -y https://yum.puppetlabs.com/puppet8-release-1.0.0-10.el8.noarch.rpm
    yum install -y puppet-agent

    # Configure Puppet Agent
    mkdir -p /etc/puppetlabs/puppet
    cat > /etc/puppetlabs/puppet/puppet.conf <<'CONFIG'
[main]
server = puppet
environment = development
runinterval = 300

[agent]
server = puppet
environment = development
CONFIG

    # Start Puppet Agent
    systemctl start puppet
    systemctl enable puppet

    # Wait for agent to start and connect
    sleep 15

    # Request certificate signing (first run)
    /opt/puppetlabs/bin/puppet agent --test --onetime || true

    # Give master time to see the cert request
    sleep 10

    echo "Puppet Agent ${count.index + 1} setup complete at $(date)"
  EOF
  )

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-puppet-agent-${count.index + 1}" })

  depends_on = [aws_instance.puppet_master, aws_security_group.puppet_sg]
}
