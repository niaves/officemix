#!/usr/bin/env bash

oauth2 () {
  source "data.conf"
  b64=$(echo -ne "${id}":"${secret}" | base64 -b 0)
  #If no refresh token exists, prompt the user to open a URL where they can authorize the app. If refresh token exists, exchange it for access token
  if [ ! -e ./$1 ]
  then
    redirect_uri="http%3A%2F%2F$callback%3A$port%2F"
    scopes=$(echo "playlist-read-private playlist-modify-private user-read-private user-top-read" | tr ' ' '%' | sed s/%/%20/g)
    auth_endpoint="https://accounts.spotify.com/authorize/?response_type=code&client_id=$id&redirect_uri=$redirect_uri&scope=$scopes"
    echo "Please visit: $auth_endpoint"
    response=$(echo -e "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin:*\r\n" | nc -l "${port}")
    code=$(echo "${response}" | grep GET | cut -d ' ' -f 2 | cut -d '=' -f 2)
    response=$(curl -s https://accounts.spotify.com/api/token -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization: Basic $b64" -d "grant_type=authorization_code&code=$code&redirect_uri=$redirect_uri")
    token=$(echo "${response}" | jq -r '.access_token')
    echo "${response}" | jq -r '.refresh_token' > $1
  else
    refresh_token=$(cat $1)
    token=$(curl -s -X POST https://accounts.spotify.com/api/token -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization: Basic $b64" -d "grant_type=refresh_token&refresh_token=$refresh_token" | jq -r '.access_token')
  fi
}

toptracks() {
  response=$(curl -X GET "https://api.spotify.com/v1/me/top/tracks?time_range=short_term&limit=$2&offset=0" -H "Accept: application/json" -H "Authorization: Bearer $1" | jq -r '.items | .[].uri')
  echo "$response" >> tracks.txt
}
addtoplaylist() {
  source 'data.conf'
  tracks=''
  while IFS='' read -r line || [[ -n "$line" ]]; do
    encodedtrack=$(php -r "echo urlencode(\"$line\");")
    tracks="${tracks}$encodedtrack,"
  done < tracks.txt

  tracks="${tracks%?}"

  addresponse=$(curl -X POST "https://api.spotify.com/v1/users/$user/playlists/$playlist/tracks?position=0&uris=$tracks" -H "Accept: application/json" -H "Authorization: Bearer $1")
}

tracksfile='tracks.txt'
maxsongs=100
usercount=$(ls -d auth/*oauth* | wc -l)
limit=$((maxsongs / usercount))

FILES=auth/*
> tracks.txt
for f in $FILES
do
  authfile=$(basename "$f")
  token=''
  oauth2 $authfile
  toptracks $token $limit
  addtoplaylist $token
done


