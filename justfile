set fallback

runtime := `which podman >/dev/null 2>&1 && echo podman || echo docker`
image   := "drupal:11-apache"

default: up

# show available commands
help:
    @just --list

# list available sites and their URLs
list:
    #!/usr/bin/env sh
    if [ ! -d sites ] || [ -z "$(ls sites/ 2>/dev/null)" ]; then
        echo "No sites yet — run: just new [name]"
        exit 0
    fi
    for site in sites/*/; do
        name=$(basename "$site")
        port=$(cat "sites/$name/port" 2>/dev/null || echo "?")
        if ls "sites/$name/files/"*.sqlite 2>/dev/null | grep -q .; then
            echo "  $name → http://localhost:$port"
        else
            echo "  $name → http://localhost:$port  (needs installer)"
        fi
    done

# create a new site (name defaults to 'default')
new name="default":
    #!/usr/bin/env sh
    if [ -d "sites/{{name}}" ]; then
        echo "Site '{{name}}' already exists — start it with: just up {{name}}"
        exit 0
    fi
    max=8000
    for p in sites/*/port; do
        [ -f "$p" ] && port=$(cat "$p") && [ "$port" -gt "$max" ] && max=$port
    done
    port=$((max + 1))
    mkdir -p "sites/{{name}}/files"
    touch "sites/{{name}}/settings.php"
    echo "$port" > "sites/{{name}}/port"
    chmod 777 "sites/{{name}}/files"
    chmod 666 "sites/{{name}}/settings.php"
    echo "Created '{{name}}' on port $port — run: just up {{name}}"

# pull the latest image
build:
    #!/usr/bin/env sh
    if [ "{{runtime}}" = "podman" ]; then
        podman machine start 2>/dev/null || true
    fi
    {{runtime}} pull {{image}}

# start a site in the foreground; Ctrl+C stops and removes the container
up site="":
    #!/usr/bin/env sh
    if [ "{{runtime}}" = "podman" ]; then
        podman machine start 2>/dev/null || true
    fi
    site="{{site}}"
    if [ -z "$site" ]; then
        if [ ! -d sites ] || [ -z "$(ls sites/ 2>/dev/null)" ]; then
            echo "No sites yet — run: just new [name]"
            exit 1
        fi
        sites=$(ls sites/)
        count=$(echo "$sites" | wc -l | tr -d ' ')
        if [ "$count" = "1" ]; then
            site="$sites"
        else
            echo "Available sites:"
            i=1
            for s in $sites; do
                echo "  $i) $s"
                i=$((i+1))
            done
            printf "Choose [1-$count]: "
            read choice
            site=$(echo "$sites" | sed -n "${choice}p")
            [ -z "$site" ] && echo "Invalid choice." && exit 1
        fi
    fi
    port=$(cat "sites/$site/port")
    {{runtime}} rm -f "drupal-$site" 2>/dev/null || true
    trap "{{runtime}} rm -f drupal-$site 2>/dev/null || true" EXIT
    if ls "sites/$site/files/"*.sqlite 2>/dev/null | grep -q .; then
        echo "Starting $site → http://localhost:$port  (Ctrl+C to stop)"
    else
        echo ""
        echo "Starting $site → http://localhost:$port"
        echo "No database yet — visit the URL to complete the one-time installer."
        echo "  Database type: SQLite  |  Database path: accept the default"
        echo ""
    fi
    {{runtime}} run \
        --name "drupal-$site" \
        --publish "$port:80" \
        --volume "$(pwd)/sites/$site/files:/var/www/html/sites/default/files" \
        --volume "$(pwd)/sites/$site/settings.php:/var/www/html/sites/default/settings.php" \
        {{image}}

# stop a leftover container (use if a previous run didn't clean up)
down site="":
    #!/usr/bin/env sh
    if [ -n "{{site}}" ]; then
        {{runtime}} rm -f "drupal-{{site}}" 2>/dev/null || true
    elif [ -d sites ]; then
        for site in sites/*/; do
            {{runtime}} rm -f "drupal-$(basename "$site")" 2>/dev/null || true
        done
    fi

# tail logs for a running site (name defaults to 'default')
logs name="default":
    {{runtime}} logs --follow "drupal-{{name}}"

# delete a site's data (prompts for confirmation)
erase name:
    #!/usr/bin/env sh
    printf "Delete all data for site '{{name}}'? Type 'yes' to confirm: "
    read answer
    if [ "$answer" = "yes" ]; then
        {{runtime}} rm -f "drupal-{{name}}" 2>/dev/null || true
        rm -rf "sites/{{name}}"
        echo "Site '{{name}}' erased."
    else
        echo "Aborted."
    fi

# delete ALL sites and data (prompts for confirmation)
erase-all:
    #!/usr/bin/env sh
    printf "Delete ALL sites and data? Type 'yes' to confirm: "
    read answer
    if [ "$answer" = "yes" ]; then
        if [ -d sites ]; then
            for site in sites/*/; do
                {{runtime}} rm -f "drupal-$(basename "$site")" 2>/dev/null || true
            done
        fi
        rm -rf sites/
        echo "All sites erased."
    else
        echo "Aborted."
    fi
