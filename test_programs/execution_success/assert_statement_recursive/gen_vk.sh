#!/usr/bin/env bash
set -eu

# Parameter validation
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 \$PROJECT_PATH \$PROJECT_NAME"
    exit 1
fi

PROJECT_PATH=$1
PROJECT_NAME=$2

ARTIFACT_FILE=$PROJECT_PATH/target/$PROJECT_NAME.json
PROOF_FILE=$PROJECT_PATH/proofs/$PROJECT_NAME.proof
BB=~/.nargo/backends/acvm-backend-barretenberg/backend_binary

if [ ! -f "$ARTIFACT_FILE" ]; then
    echo "Error: File $ARTIFACT_FILE not exist. Please run 'nargo compile'"
    exit 1
fi

if [ ! -f "$PROOF_FILE" ]; then
    echo "Error: File $PROOF_FILE not exist. Please run 'nargo prove'"
    exit 1
fi

# Generate vk
jq -r '.bytecode' $ARTIFACT_FILE | base64 -d > acir.tmp
$BB write_vk -b acir.tmp -o vk.tmp
$BB vk_as_fields -k vk.tmp -o vk_fields.tmp

VK_HASH=$(jq -r '.[0]' vk_fields.tmp)
echo "vk_hash = $VK_HASH" > target/temp.toml

VK_AS_FIELDS=$(jq -r '.[1:]' vk_fields.tmp)
echo "vk_as_fields = $VK_AS_FIELDS" >> target/vk_hash_and_fields.toml
echo "Generated target/vk_hash_and_fields.toml"

# Convert hex proof to binary format
xxd -r -p ./proofs/$PROJECT_NAME.proof > ./proofs/$PROJECT_NAME.bin.proof
# Adding one public parameter with value 2
echo -n '0000000000000000000000000000000000000000000000000000000000000002' | xxd -r -p >> ./proofs/$PROJECT_NAME.bin.proof

# Convert proof binary to toml
$BB proof_as_fields -k vk.tmp -p proofs/$PROJECT_NAME.bin.proof -o target/proof_as_fields.toml
echo "Generated target/proof_as_fields.toml"

# Cleanup
rm acir.tmp
rm vk_fields.tmp
rm vk.tmp
