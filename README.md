# Terraform Blue/Green High Availability Web Tier (SSM-Only)

This project demonstrates an enterprise-style, highly available web tier built using Terraform. It implements blue/green deployments, Auto Scaling Groups, and secure SSM-only access — without SSH, bastion hosts, or NAT gateways.

The intent is to model real-world infrastructure patterns rather than a toy demo.

---

## Architecture Overview

Core components:
- Application Load Balancer (public)
- Two Auto Scaling Groups (Blue / Green) in private subnets
- Launch Templates using Amazon Linux 2023
- Instance Metadata Service v2 (IMDSv2)
- AWS Systems Manager (SSM) for access and management

Traffic flow:
```

Internet
→ Application Load Balancer
→ Weighted Target Groups (Blue / Green)
→ Auto Scaling Groups (Private Subnets)

````

---

## Security Model

- No SSH keys
- No inbound port 22
- No bastion host
- No NAT gateway
- All instance access via SSM Session Manager
- IMDSv2 enforced

Compute resources are isolated in private subnets and exposed only through the load balancer.

---

## Key Features

- Blue/green deployment using ALB weighted target groups
- Instant traffic cutover with no instance replacement
- Rolling instance refresh on launch template updates
- Stateless application bootstrapping via user-data
- Self-healing through Auto Scaling Groups

---

## Demo Workflow

1. Traffic is routed to the Blue environment
2. Application response is verified through the ALB
3. Traffic weights are shifted to Green
4. Cutover completes without downtime

Example response:
```html
<h1>BLUE</h1>
<p>Instance: i-0abc123...</p>
````

After cutover:

```html
<h1>GREEN</h1>
<p>Instance: i-0def456...</p>
```

---

## Instance Access (SSM Only)

Instances are accessed using AWS Systems Manager:

```bash
aws ssm start-session --target <instance-id>
```

Validation inside the instance:

```bash
whoami
sudo systemctl status web.service
sudo ss -lntp | grep ':22' || echo "No SSH listener"
```

---

## Technology Stack

* Terraform
* AWS EC2, ALB, Auto Scaling
* AWS Systems Manager (SSM)
* Amazon Linux 2023
* IMDSv2
* systemd
* Python (http.server)

---

## Cost Considerations

This project is intentionally designed to minimize cost:

* No NAT gateway
* No WAF
* Uses public ALB only
* Free-tier compatible components where possible

To clean up resources:

```bash
terraform destroy
```

---

## Motivation

This project reflects patterns commonly used in production environments:

* Immutable infrastructure
* Secure-by-default access
* Blue/green deployment strategies
* Infrastructure as Code

---

## Future Work

* Simulated failure scenarios and recovery
* Gradual canary deployments
* CloudWatch metrics and alarms
* ALB access logging
* Multi-region architectures

---

## Screenshots

See the `screenshots/` directory for:

* ALB responses (Blue / Green)
* SSM session access
* SSH disabled verification
* Terraform apply output

