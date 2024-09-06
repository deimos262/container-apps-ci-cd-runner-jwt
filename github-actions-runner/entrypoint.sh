#!/usr/bin/env bash

set -o pipefail
set -x
client_id=$clientID
pem=$PRIVATE_CERT

now=$(date +%s)
iat=$((${now} - 60)) # Issues 60 seconds in the past
exp=$((${now} + 600)) # Expires 10 minutes in the future

b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

header_json='{
    "typ":"JWT",
    "alg":"RS256"
}'
# Header encode
header=$( echo -n "${header_json}" | b64enc )

payload_json="{
    \"iat\":${iat},
    \"exp\":${exp},
    \"iss\":\"${client_id}\"
}"
# Payload encode
payload=$( echo -n "${payload_json}" | b64enc )

# Signature
header_payload="${header}"."${payload}"
signature=$(
    openssl dgst -sha256 -sign <(echo -n "${pem}") <(echo -n "${header_payload}") | b64enc
)
echo "signature: $signature"

# Create JWT
JWT="${header_payload}"."${signature}"

export INSTALLATION_TOKEN=$(curl -X POST -fsSL \
 -H "Authorization: Bearer $JWT" \
 -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/app/installations/$installationID/access_tokens | jq -r '.token')


# Retrieve a short lived runner registration token using the PAT
export REGISTRATION_TOKEN="$(curl -X POST -fsSL \
  -H 'Accept: application/vnd.github.v3+json' \
  -H "Authorization: Bearer $INSTALLATION_TOKEN" \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "$REGISTRATION_TOKEN_API_URL" \
  | jq -r '.token')"
  
export UNREGISTRATION_TOKEN="$(curl -X POST -fsSL \
  -H 'Accept: application/vnd.github.v3+json' \
  -H "Authorization: Bearer $INSTALLATION_TOKEN" \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "$REGISTRATION_TOKEN_API_URL" \
  | jq -r '.token')"
  
echo "UNREGISTRATION_TOKEN: $UNREGISTRATION_TOKEN" 

./config.sh --url $GH_URL --token $REGISTRATION_TOKEN --runnergroup $RUNNER_GROUP --labels $RUNNER_LABELS --unattended --ephemeral && ./run.sh

trap './config.sh remove --token $UNREGISTRATION_TOKEN; exit 0' SIGTERM
