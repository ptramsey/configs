server-dev() {
    if sudo docker ps | grep -q server-dev; then
        sudo docker attach server-dev
    elif sudo docker ps -a | grep -q server-dev; then
        sudo docker start server-dev
        sudo docker attach server-dev
    else
        sudo docker run -i -t $(seq 8000 8004 | sed 's/\(.*\)/-p \1:\1/') --name=server-dev -v /big:/big ptr:fs-server-dev /bin/bash -il
    fi
}
