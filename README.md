# OfficeMix

Create a playlist with the most heard tracks of your co-workers, friends, etc.

## Getting Started

### Prerequisites

- [JQ](https://stedolan.github.io/jq/)

### How to use
#### Configuration
1. Create an folder named *auth*
2. You will need to register a new Application at https://developer.spotify.com/my-applications
3. Take note of the Client ID and Client Secret
4. For the 'Redirect URI' you will need to use http://localhost:8082/ (or any other port)
5. Create a new file `data.conf` and replace `id` and `secret` with the values from Steps 1

```
id="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
secret="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
callback="localhost"
port=8082
user="cccccccccccccccccccccccccccccccc"
playlist="dddddddddddddddddddddddddddddddd"
```

## Usage
1. clone git
2. `cd officemix && chmod +x officemix.sh`
3. `./officemix.sh -add #name` to add a new user'
4. `./officemix.sh`