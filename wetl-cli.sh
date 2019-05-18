#!/bin/bash

# use another API key - possible rate limit reach
API_KEY="i8tq2MrALERSuz11xR7vaogtnKTHjjtaTdaX79L3"

#retrieve jwt
echo "Retrieving JSON Web token..."
JWT=$(curl -s -X POST "https://dev.wetransfer.com/v2/authorize" \
	-H "Content-Type: application/json" \
	-H "x-api-key: $API_KEY" \
	-d '{"user_identifier":"5ee6e98e-ddee-4f5b-9d03-7bd4d91aa05f"}' | jq -r '.token') 
testfile=$1
size=$(wc -c $testfile | cut -d" " -f1)

echo "Creating transfer..."
create_transfer(){
	resp=$(curl -s -X POST "https://dev.wetransfer.com/v2/transfers" \
	-H "Content-Type: application/json" \
	-H "x-api-key: $API_KEY" \
	-H "Authorization: Bearer $JWT" \
	-d '
	{
		"message":"New wetl-cli upload",
		"files":[
		{
			"name":"'$testfile'",
			"size":'$size'
		}
	]
}')

#save transfer id, file id in ids array
ids+=( $( jq -r '"\(.id) \(.files[] | .id)"' <<< "$resp" ) )
#echo $resp
#echo ${ids[1]}

echo "Get S3 upload URL..."
uploadurl=$(curl -s -X GET "https://dev.wetransfer.com/v2/transfers/${ids[0]}/files/${ids[1]}/upload-url/1" \
	-H "x-api-key: $API_KEY" \
	-H "Authorization: Bearer $JWT" | jq -r '.url')

echo "Upload file to S3..."
curl -s -T "$testfile" "$uploadurl" --progress-bar

echo "Inform WeTransfer API of the upload..."
curl -s -X PUT "https://dev.wetransfer.com/v2/transfers/${ids[0]}/files/${ids[1]}/upload-complete" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $JWT" \
  -d '{"part_numbers":1}' > /dev/null

echo "Finalizing Transfer..."
finalise=$(curl -s -X PUT "https://dev.wetransfer.com/v2/transfers/${ids[0]}/finalize" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $JWT" | jq -r '.url')
echo "Access your file from: $finalise"
}

time create_transfer
