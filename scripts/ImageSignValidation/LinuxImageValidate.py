import json
import subprocess
import os
import logging

logging.basicConfig(level=logging.INFO)

# Resolve trusted paths relative to this script's own directory rather than the
# caller's current working directory. This prevents an attacker who controls the
# launch directory from planting a malicious `notation` binary (or cert/policy
# files) that would run as the script user and fake successful signature
# verification. Mirrors the $PSScriptRoot pattern used by WindowsImageValidate.ps1.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NOTATION = os.path.join(SCRIPT_DIR, "notation")
CA_CERT = os.path.join(SCRIPT_DIR, "ca.crt")
TSA_CERT = os.path.join(SCRIPT_DIR, "tsa.crt")

def run_command(command):
    try:
        subprocess.run(command, check=True, capture_output=True, text=True)
        return True
    except subprocess.CalledProcessError as e:
        return False


def verify_image(image):
    trust_data = {
        "version": "1.0",
        "trustPolicies": [
            {
                "name": "supplychain",
                "registryScopes": ["*"],
                "signatureVerification": {"level": "strict"},
                "trustStores": ["ca:supplychain", "tsa:esrp"],
                "trustedIdentities": [
                    "x509.subject: CN=Microsoft SCD Products RSA Signing,O=Microsoft Corporation,L=Redmond,ST=Washington,C=US"
                ]
            }
        ]
    }

    trust_json = json.dumps(trust_data)
    trust_path = os.path.join(SCRIPT_DIR, "trust.json")
    with open(trust_path, "w") as f:
        f.write(trust_json)

    run_command([NOTATION, "policy", "import", trust_path, "--force"])
    run_command([NOTATION, "policy", "show"])
    result = run_command([NOTATION, "verify", image, "--verbose"])
    if not result:
        run_command([NOTATION, "inspect", image, "--verbose"])
    os.remove(trust_path)
    return result

def ensure_certs(cert_type, store, cert_name, cert_path):
    result = subprocess.run([NOTATION, "cert", "ls", "--type", cert_type, "--store", store, cert_name], capture_output=True, text=True, check=True)
    if not result.stdout.strip():
        run_command([NOTATION, "cert", "add", "--type", cert_type, "--store", store, cert_path])
        run_command([NOTATION, "cert", "ls", "--type", cert_type])

def get_crictl_images_with_none_tag():
    # Run the crictl command and capture the output
    command = "sudo crictl images --output=json | jq -r '.images[] | \"\\(.repoTags[0])=\\(.repoDigests[0])\"'"
    result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
    # Check for errors
    if result.returncode != 0:
        logging.error(f"Error: {result.stderr}")
        return []

    output = result.stdout
    # Split the output into lines and remove any blank lines
    lines = [line for line in output.split('\n') if line.strip()]
    return lines

def ensure_trust():
    tool_name = "notation"
    ensure_certs("ca", "supplychain", "ca.crt", CA_CERT)
    ensure_certs("tsa", "esrp", "tsa.crt", TSA_CERT)

    images = get_crictl_images_with_none_tag()
    failed_images = []
    passed_images = []
    for image in images:
        if '=' in image:
            key, value = image.split('=')
            imageValue = ""
            if 'null' in value:
                imageValue = key
            else:
                imageValue = value
            verification_result = verify_image(imageValue)
            if not verification_result:
                failed_images.append(imageValue)
            else:
                passed_images.append(imageValue)
    image_dict = {
        "failed_signed_images": failed_images,
        "passed_signed_images": passed_images
    }
        
    # Define the path to the JSON file
    json_file_path = "imagevalidation_results_linux.json"

    # Write the dictionary to the JSON file
    with open(json_file_path, 'w') as json_file:
        json.dump(image_dict, json_file, indent=4)
    logging.info(f"Sign image result present in file : {json_file_path}")

if __name__ == "__main__":
    ensure_trust()