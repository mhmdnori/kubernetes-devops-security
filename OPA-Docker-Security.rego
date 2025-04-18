package main

# Do Not store secrets in ENV variables
secrets_env = [
    "passwd",
    "password",
    "pass",
    "secret",
    "key",
    "access",
    "api_key",
    "apikey",
    "token",
    "tkn"
]

deny[msg] {
    some i, j, k
    input[i].Cmd == "env"
    val = input[i].Value
    contains(lower(val[j]), secrets_env[k])
    msg = sprintf("Line %d: Potential secret in ENV key found: %s", [i, val])
}

# Only use trusted base images
deny[msg] {
    some i
    input[i].Cmd == "from"
    val = split(input[i].Value[0], "/")
    count(val) > 1
    msg = sprintf("Line %d: use a trusted base image", [i])
}

# Do not use 'latest' tag for base image
deny[msg] {
    some i
    input[i].Cmd == "from"
    parts = split(input[i].Value[0], ":")
    count(parts) == 2
    tag = parts[1]
    tag == "latest"
    msg = sprintf("Line %d: do not use 'latest' tag for base images", [i])
}

# Avoid curl bashing
deny[msg] {
    some i
    input[i].Cmd == "run"
    val = concat(" ", input[i].Value)
    matches = regex.find_n("(curl|wget)[^|^>]*[|>]", lower(val), -1)
    count(matches) > 0
    msg = sprintf("Line %d: Avoid curl bashing", [i])
}

# Do not upgrade your system packages
warn[msg] {
    some i
    input[i].Cmd == "run"
    val = concat(" ", input[i].Value)
    matches = regex.match(".*?(apk|yum|dnf|apt|pip).+?(install|upgrade|update).*", lower(val))
    matches == true
    msg = sprintf("Line: %d: Do not upgrade system packages: %s", [i, val])
}

# Do not use ADD if possible
deny[msg] {
    some i
    input[i].Cmd == "add"
    msg = sprintf("Line %d: Use COPY instead of ADD", [i])
}

# Any user...
any_user {
    some i
    input[i].Cmd == "user"
}

deny[msg] {
    not any_user
    msg = "Do not run as root, use USER instead"
}

# ... but do not root
forbidden_users = [
    "root",
    "toor",
    "0"
]

deny[msg] {
    some i
    input[i].Cmd == "user"
    users = [name | name = input[i].Value[_]]
    count(users) > 0
    lastuser = users[count(users)-1]
    some part
    contains(lower(lastuser[part]), forbidden_users[_])
    msg = sprintf("Line %d: Last USER directive (USER %s) is forbidden", [i, lastuser])
}

# Do not sudo
deny[msg] {
    some i
    input[i].Cmd == "run"
    val = concat(" ", input[i].Value)
    contains(lower(val), "sudo")
    msg = sprintf("Line %d: Do not use 'sudo' command", [i])
}
