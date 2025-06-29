import json
import subprocess
import os
import logging

logging.basicConfig(level=logging.INFO)

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
    with open("trust.json", "w") as f:
        f.write(trust_json)

    run_command(["./notation", "policy", "import", "trust.json", "--force"])
    run_command(["./notation", "policy", "show"])
    result = run_command(["./notation", "verify", image, "--verbose"])
    if not result:
        run_command(["./notation", "inspect", image, "--verbose"])
    os.remove("trust.json")
    return result

def ensure_certs(cert_type, store, cert_name):
    result = subprocess.run(["./notation", "cert", "ls", "--type", cert_type, "--store", store, cert_name], capture_output=True, text=True, check=True)
    if not result.stdout.strip():
        run_command(["./notation", "cert", "add", "--type", cert_type, "--store", store, cert_name])
        run_command(["./notation", "cert", "ls", "--type", cert_type])

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
    ensure_certs("ca", "supplychain", "ca.crt")
    ensure_certs("tsa", "esrp", "tsa.crt")

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