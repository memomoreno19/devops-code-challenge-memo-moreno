# AWS Architecture for the FastAPI Service

## Overview
This solution deploys a containerized FastAPI application in a highly available, multi-AZ AWS environment. The architecture is designed to satisfy the core requirements for resiliency, scalability, security, and operational simplicity.

The platform should run in a VPC with public and private subnets across at least two availability zones. Public ingress is handled by an Application Load Balancer (ALB), while the application workloads and data stores remain in private subnets to reduce exposure.

```text
                     ┌────────────────────────────┐
                     │        Internet            │
                     └────────────┬───────────────┘
                                  │
                                  ▼
                     ┌────────────────────────────┐
                     │  Application Load Balancer │
                     │  (public subnets, 2 AZs)   │
                     └────────────┬───────────────┘
                                  │
                     ┌────────────┴───────────────┐
                     │                             │
          ┌──────────▼──────────┐     ┌──────────▼──────────┐
          │ ECS Tasks / ASG     │     │ ECS Tasks / ASG     │
          │ FastAPI App         │     │ FastAPI App         │
          │ AZ A                │     │ AZ B                │
          └──────────┬──────────┘     └──────────┬──────────┘
                     │                             │
                     │                             │
          ┌──────────▼──────────┐     ┌──────────▼──────────┐
          │ ElastiCache Redis   │     │ Amazon RDS Postgres │
          │ (cache / sessions)  │     │ (primary DB)        │
          └─────────────────────┘     └─────────────────────┘
```

## 1. Core Components

### Application tier
- FastAPI service containerized with Docker
- Runs behind an ALB for HTTP traffic distribution
- Deployed as an ECS service with autoscaling enabled
- Uses a task definition with CPU, memory, health checks, and port mapping
- The container runs on port 8000 and is exposed internally through the ALB

### Load balancing and entry point
- ALB receives incoming traffic from the internet
- Uses health checks to route traffic only to healthy tasks
- Distributes traffic across the application containers in both availability zones
- Terminates TLS at the load balancer if HTTPS is enabled with ACM

### Compute orchestration
- ECS cluster manages scheduling and lifecycle of the application containers
- Capacity Providers are attached to the cluster and linked to an Auto Scaling Group
- The ASG automatically adds or removes EC2 capacity based on workload demand
- This eliminates manual EC2 provisioning and simplifies rolling deployments

### Data tier
- Amazon RDS for PostgreSQL stores durable application data
- Amazon ElastiCache for Redis supports caching and transient session storage
- Database and cache sit in private subnets to prevent direct public access

## 2. Network Design

### VPC layout
- Public subnets: ALB and NAT gateway paths
- Private subnets: ECS tasks, Redis, and RDS
- Two availability zones for redundancy and failover

### Traffic flow
- Internet traffic reaches the ALB in public subnets
- ALB forwards traffic to ECS tasks in private subnets
- ECS tasks access Redis and RDS privately over the VPC network
- Outbound internet access for package updates or external APIs is routed through NAT or a private egress model

### Security boundaries
- Security groups restrict traffic by port and source
- ALB allows inbound HTTP/HTTPS only
- ECS app tasks allow inbound traffic only from the ALB
- RDS allows inbound only from the app security group
- Redis only accepts traffic from the application layer
- No public IPs are assigned to the application containers or database layer

## 3. High Availability and Failover

The design is intentionally multi-AZ to reduce blast radius during an infrastructure failure.

- ALB spans both AZs to continue serving traffic if one zone becomes unhealthy
- ECS service runs containers in more than one AZ
- ASG scales capacity across zones to maintain target availability
- RDS should be configured as a Multi-AZ deployment for primary failover support
- Redis can be deployed in a primary/replica pattern or a managed cluster to improve resilience

If one availability zone fails, traffic is rerouted to healthy instances in the remaining AZ without requiring a full service outage.

## 4. Orchestration and Deployment Model

Instead of managing raw EC2 instances manually, the environment should use ECS with a container-first deployment model.

- ECS Cluster: created for the application environment
- Capacity Provider: linked to ASG to dynamically scale compute
- ECS Task Definition: defines the FastAPI container, environment variables, CPU/RAM limits, and port mappings
- Service-level deployment: allows rolling updates and health checks during version releases
- Container port: map the app container port to host port 8000 for the FastAPI service

This provides automated scheduling, self-healing, and easier rollout control when new application versions are deployed.

## 5. Operational Considerations

### Monitoring and health checks
- ALB health checks validate app health before routing traffic
- Container health checks detect unhealthy tasks and replace them automatically
- CloudWatch logs, metrics, and alarms should track CPU, memory, errors, and latency

### Scaling
- Horizontal scaling should be enabled for ECS tasks based on CPU and memory metrics
- ASG capacity should scale in response to task demand
- Add burst handling for traffic spikes without downtime

### Secrets and configuration
- Store environment variables and secrets in AWS Secrets Manager or SSM Parameter Store
- Avoid embedding DB credentials or tokens directly in the container image

## 6. Security Best Practices

- Restrict inbound access to the minimum required ports
- Use private subnets for app/data workloads
- Use IAM roles instead of static credentials
- Enable only required AWS services for the application runtime
- Use HTTPS termination at the ALB with ACM-managed certificates
- Consider WAF in front of the ALB for additional web protection

## 7. Recommended Final Layout

- VPC with public and private subnets in 2 AZs
- Internet Gateway attached to the VPC
- ALB in public subnets
- ECS service in private subnets
- Redis in private subnets
- PostgreSQL in private subnets, ideally with Multi-AZ enabled
- NAT gateway or similar egress path for private resources
- CloudWatch + alarms + logs for observability

## 8. Summary
This architecture gives the FastAPI application a production-oriented deployment pattern with load balancing, private networking, database persistence, and fault tolerance across multiple availability zones. It keeps the system scalable and operationally simpler than managing standalone EC2 instances while maintaining a strong security posture.
