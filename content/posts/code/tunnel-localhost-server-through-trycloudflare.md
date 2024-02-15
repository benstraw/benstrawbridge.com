+++
title = 'Tunnel Localhost Server Through Trycloudflare'
date = 2024-02-14T15:06:29-08:00
draft = true
+++

This post is an update to this post -- https://nathancraddock.com/blog/hugo-server-on-local-and-public-networks

To run hugo on the local network on localhost AND bind to your local network IP address you can use - 
```
$ hugo server --bind 0.0.0.0
```

I use zsh so I didn't use the fish script but instaed added a function to `~/.zshrc` called `hugo_with_tunnel`

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
