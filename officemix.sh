#!/usr/bin/env bash

oauth2 () {
  source "data.conf"
  b64=$(echo -ne "${id}":"${secret}" | base64 -b 0)
  #If no refresh token exists, prompt the user to open a URL where they can authorize the app. If refresh token exists, exchange it for access token
  if [ ! -e ./$1 ]
  then
    redirect_uri="http%3A%2F%2F$callback%3A$port%2F"
    scopes=$(echo "playlist-modify-public playlist-modify-private user-top-read" | tr ' ' '%' | sed s/%/%20/g)
    auth_endpoint="https://accounts.spotify.com/authorize/?response_type=code&client_id=$id&redirect_uri=$redirect_uri&scope=$scopes"
    echo "Please visit: $auth_endpoint"
    response=$(echo -e "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin:*\r\n" | nc -l "${port}")
    code=$(echo "${response}" | grep GET | cut -d ' ' -f 2 | cut -d '=' -f 2)
    response=$(curl -s https://accounts.spotify.com/api/token -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization: Basic $b64" -d "grant_type=authorization_code&code=$code&redirect_uri=$redirect_uri")
    token=$(echo "${response}" | jq -r '.access_token')
    refresh=$(echo "${response}" | jq -r '.refresh_token')
    echo "$2;$refresh" > $1
  else
    line=$(head -n 1 $1)
    arr=$(echo $line | tr ";" "\n")

    authuser="$(cut -d';' -f1 <<< $line)"
    refresh_token="$(cut -d';' -f2 <<< $line)"

    token=$(curl -s -X POST https://accounts.spotify.com/api/token -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization: Basic $b64" -d "grant_type=refresh_token&refresh_token=$refresh_token" | jq -r '.access_token')
  fi
}

toptracks() {
  response=$(curl -X GET "https://api.spotify.com/v1/me/top/tracks?time_range=short_term&limit=$2" -H "Accept: application/json" -H "Authorization: Bearer $1" | jq -r '.items | .[].uri')
  echo "$response" >> $3
}
addtoplaylist() {
  source 'data.conf'

  oauth2 $1

  tracks=''
  while IFS='' read -r line || [[ -n "$line" ]]; do
    encodedtrack=$(php -r "echo urlencode(\"$line\");")
    tracks="${tracks}$encodedtrack,"
  done < $2

  tracks="${tracks%?}"

  addresponse=$(curl -X POST "https://api.spotify.com/v1/users/$authuser/playlists/$playlist/tracks?position=0&uris=$tracks" -H "Accept: application/json" -H "Authorization: Bearer $token")
}

clean() {
  rm -rf $1
}

clearplaylist() {
  source "data.conf"
  maxallowed=100

  oauth2 $1

  total=$(curl -X GET "https://api.spotify.com/v1/users/$user/playlists/$playlist" -H "Authorization: Bearer $token" | jq -r '.tracks.total')

  tmp=$total

  if [ "$total" -ne 0 ]
  then  
    snapshot=$(curl -X GET "https://api.spotify.com/v1/users/$user/playlists/$playlist" -H "Authorization: Bearer $token" | jq -r '.snapshot_id')
        
    while [ $tmp -gt 0 ]
    do
        count=$tmp
        if [ $tmp -gt $maxallowed ]
        then
          count=maxallowed
        fi
        position='['

        for (( c=0; c<$count; c++ ))
        do  
           position="$position$c,"
        done
        position="${position%?}]"
        snapshot=$(curl -X DELETE "https://api.spotify.com/v1/users/$user/playlists/$playlist/tracks" -H "Authorization: Bearer $token" -H "Content-Type: application/json" --data "{\"positions\":$position,\"snapshot_id\":\"$snapshot\"}" | jq -r '.snapshot_id')
        tmp=$(echo $(( tmp - count )))
    done
  fi
}

folder="auth"
mastertoken="master.token"
mkdir -p auth

if [ ! -d $folder ]; then
  mkdir -p $folder
fi

if [ $# -eq 2 ]
then 
  if [ "$1" == "-init" ]
  then
    oauth2 $mastertoken $2
  else
      echo "unkown parameter"
  fi
fi
if [ $# -eq 3 ]
then 
  if [ "$1" == "-add" ]
  then
    oauth2 "$folder/oauth.$2" $3
  else
      echo "unkown parameter"
  fi
else
  if [ $# -eq 0 ]
  then
    maxsongs=75
    clearplaylist $mastertoken $maxsongs
    tracksfile='tracks.txt'
    > $tracksfile

    for f in "$folder/*"
    do
      authfile=$(basename "$f")
      token=''
      authuser=''
      oauth2 "$folder/$authfile"
      toptracks $token $maxsongs $tracksfile
      addtoplaylist $mastertoken $tracksfile
    done
    clean $tracksfile
  fi
fi



