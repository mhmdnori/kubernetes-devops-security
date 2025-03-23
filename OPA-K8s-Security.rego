package main

# Policy 1: Containers should not run as root
deny[msg] {
    some container
    input.spec.template.spec.containers[container]
    not input.spec.template.spec.securityContext.runAsNonRoot
    msg = sprintf("Container '%s' must run as non-root", [container])
}

# Policy 2: Set resource limits and requests
deny[msg] {
    some container
    input.spec.template.spec.containers[container]
    not input.spec.template.spec.containers[container].resources.limits
    msg = sprintf("Container '%s' must have resource limits defined", [container])
}

deny[msg] {
    some container
    input.spec.template.spec.containers[container]
    not input.spec.template.spec.containers[container].resources.requests
    msg = sprintf("Container '%s' must have resource requests defined", [container])
}

# Policy 3: Use secure images
deny[msg] {
    some container
    input.spec.template.spec.containers[container]
    image := input.spec.template.spec.containers[container].image
    contains(image, ":latest")
    msg = sprintf("Container '%s' uses the 'latest' tag, which is insecure", [container])
}


# Policy 4: Disable unnecessary ports
deny[msg] {
    some container
    input.spec.template.spec.containers[container]
    ports := input.spec.template.spec.containers[container].ports
    count(ports) > 1
    msg = sprintf("Container '%s' has more than one port open", [container])
}

# Policy 5: Disable privileged mode
deny[msg] {
    some container
    input.spec.template.spec.containers[container]
    input.spec.template.spec.securityContext.privileged
    msg = sprintf("Container '%s' is running in privileged mode", [container])
}