# Enable this feature to use EIPs rather than dynamic IPs
variable "eipenable" {
    default = false
}


# Set the list of IPs we want to whitelist to access the exposed resources. [] if you want to expose it to the internet
variable "cidr_whitelist" {
  default = [] # ["195.95.131.0/24"]
}

# Timeout since the machine is marked to terminate, time scenario happens when the number of tasks require less workers. 
# This value should be set based on the maximum time the tool is expected to run.
variable "heartbeat_timeout" {
    # heartbeat_timeout - (Optional) Defines the amount of time, in seconds, that can elapse before the lifecycle hook times out. 
    # When the lifecycle hook times out, Auto Scaling performs the action defined in the DefaultResult parameter
    default = "900"
}

# maximum number of terminating workers has been reached, no scaling is going to happen until those workers timeout or the tools running on them finishes
variable "maximum_number_of_terminating_machines" {
    default = 2
}

# max ec2 instances for the autoscaling group
variable "max_workers" {
    default = 3
}

# max number of queued tasks  per worker
variable "max_queued_tasks_per_worker" {
    default = 10
}

variable "ami" {
    # ami-0d5eff06f840b45e9 # basic, private!
    # ami-0bfa37e1a7e2bb7e5 # reconftw, private!
    # ami-07f6ac956d338c0a4 # reconftw, private!
    # You have to create your own AMI, then create an snapshot with the tools and deps of your preference.
    # Alternatively, you can choose one from AMI Catalog.
    default = ""
}

variable "instance_type" {
    default = "t2.micro" # t2.small
}

# Set the retention time for logs and the expiration of the archive table items.
# Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, and 0
variable "retention_time" {
    default = "7"
}