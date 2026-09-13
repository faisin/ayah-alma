import os
import time
import oci

# Load credentials from GitHub Secrets
user_ocid = os.environ.get("OCI_USER_OCID")
tenancy_ocid = os.environ.get("OCI_TENANCY_OCID")
region = os.environ.get("OCI_REGION")
subnet_id = os.environ.get("OCI_SUBNET_ID")
fingerprint = os.environ.get("OCI_FINGERPRINT")
key_content = os.environ.get("OCI_KEY_FILE")

# Setup OCI Configuration
config = {
    "user": user_ocid,
    "key_content": key_content,
    "fingerprint": fingerprint,
    "tenancy": tenancy_ocid,
    "region": region
}

compute_client = oci.core.ComputeClient(config)
identity_client = oci.identity.IdentityClient(config)

# Get Availability Domain
ad = identity_client.list_availability_domains(tenancy_ocid).data[0].name

# Configuration for Always Free ARM Instance (4 OCPU, 24GB RAM)
# Change shape to "VM.Standard.E2.1.Micro" if you want x86 1 Core 1GB
shape = "VM.Standard.A1.Flex"
ocpus = 4
memory_in_gbs = 24

# Oracle Linux 8 Image OCID for your region
# You can update image_id if specific OS version is needed
launch_details = oci.core.models.LaunchInstanceDetails(
    compartment_id=tenancy_ocid,
    availability_domain=ad,
    shape=shape,
    shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
        ocpus=ocpus,
        memory_in_gbs=memory_in_gbs
    ),
    create_vnic_details=oci.core.models.CreateVnicDetails(
        subnet_id=subnet_id,
        assign_public_ip=True
    ),
    source_details=oci.core.models.InstanceSourceViaImageDetails(
        image_id=compute_client.list_images(
            compartment_id=tenancy_ocid,
            operating_system="Oracle Linux",
            operating_system_version="8",
            shape=shape
        ).data[0].id
    ),
    display_name="AutoCreatedInstance"
)

print("Attempting to create Oracle Cloud Instance...")

try:
    response = compute_client.launch_instance(launch_details)
    print("SUCCESS! Instance created with ID:", response.data.id)
except oci.exceptions.ServiceError as e:
    if e.status == 500 or "Out of host capacity" in str(e):
        print("Out of capacity. Will try again on the next schedule.")
    else:
        print("OCI Error:", e.message)
except Exception as e:
    print("Unexpected error:", str(e))
