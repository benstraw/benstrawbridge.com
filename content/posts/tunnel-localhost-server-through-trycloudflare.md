+++
title = 'Tunnel Localhost Server Through Cloudflare'
date = 2024-02-14T14:06:29-08:00
# draft = true
tags = [
    "localhost server",
    "networking",
    "shell scripting",
    "development environment",
    "workflow optimization",
    "zsh script",
    "Cloudflare tunneling service",
    "NGROK"
]
homeFeatureIcon = "fa-solid fa-car-tunnel"

+++

This is something I have done in the past and it usually involved pretty in-depth knowledge of the shell and networking, but now there is a free service that makes it oh-so-easy to spin up a tunnel with a public human readable domain name for temporary viewing of your local network development environment on the internet. This is very useful for presentations, working with colleagues, or just briefly sharing your work.  I first found out about this from [Nathan Craddock's blog](https://nathancraddock.com/blog/hugo-server-on-local-and-public-networks), which you should read if you want more details, but I made a few significant changes to his workflow worth a short writeup.

### 0.0.0.0 trick

You don't have to choose between binding hugo, or any local server, to just localhost/127.0.0.1 or an ip in the 192.168 range, you can bind to all all IP addresses available in your network stack with 0.0.0.0. To run hugo on the local network on localhost AND bind to your local network IP address you can use -

```bash
$ hugo server --bind 0.0.0.0
```

### The zsh script

I use zsh so I didn't use his fish script but instead wrote this function which I added to `~/.zshrc` and called `hugo_with_tunnel`.

```zsh
# Function to run Hugo through Cloudflare tunnel
function hugo_with_tunnel() {
    # Create a temporary file
    tmpfile=$(mktemp)

    # Start cloudflared tunnel in the background
    cloudflared tunnel --url http://localhost:1313 2> $tmpfile &

    # Capture the PID of the last background process
    last_pid=$!

    # Wait for the server to start
    echo -n "Waiting for Cloudflare tunnel to start"
    cloudflare_url=""
    while [[ -z $cloudflare_url ]]; do
        echo -n .
        cloudflare_url=$(grep --color=never -o -m1 "http.*trycloudflare.com" $tmpfile)
        sleep 1
    done
    echo -e " started\n"

    # Run Hugo through the tunnel
    hugo server --appendPort=false --baseURL $cloudflare_url "$@"

    # Shut down the tunnel
    echo -e "\nShutting down tunnel"
    kill $last_pid
    sleep 1
}
```

It can still be called with any hugo parameters, such as -D to publish drafts.

So now you can run -

```
$ hugo_with_tunnel -D
```

### Alternative - NGROK

https://ngrok.com/