import os
import oci

# Load credentials from GitHub Secrets
user_ocid = os.environ.get("OCI_USER_OCID")
tenancy_ocid = os.environ.get("OCI_TENANCY_OCID")
region = os.environ.get("OCI_REGION")
subnet_id = os.environ.get("OCI_SUBNET_ID")
fingerprint = os.environ.get("OCI_FINGERPRINT")
key_content = os.environ.get("OCI_KEY_FILE")
ssh_public_key = os.environ.get("OCI_SSH_PUBLIC_KEY") # Tambahan untuk login SSH

# Setup OCI Configuration
config = {
    "user": user_ocid,
    "key_content": key_content,
    "fingerprint": fingerprint,
    "tenancy": tenancy_ocid,
    "region": region
}

try:
    compute_client = oci.core.ComputeClient(config)
    identity_client = oci.identity.IdentityClient(config)

    # Get Availability Domain
    ad = identity_client.list_availability_domains(tenancy_ocid).data[0].name

    shape = "VM.Standard.A1.Flex"
    ocpus = 4
    memory_in_gbs = 24

    # Cari Image Oracle Linux 8 secara aman tanpa crash
    images = compute_client.list_images(
        compartment_id=tenancy_ocid,
        operating_system="Oracle Linux",
        operating_system_version="8.8" # Atau gunakan versi 8
    ).data

    if not images:
        # Fallback jika 8.8 tidak ditemukan, ambil image Oracle Linux apa saja yang ada
        images = compute_client.list_images(
            compartment_id=tenancy_ocid,
            operating_system="Oracle Linux"
        ).data

    image_id = images[0].id

    # Detail Peluncuran Instance
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
            image_id=image_id
        ),
        metadata={
            # Memasang SSH Key agar kamu bisa login sebagai user 'opc' atau 'root'
            "ssh_authorized_keys": ssh_public_key if ssh_public_key else ""
        },
        display_name="AYAH-ALMA-ARM-VPS"
    )

    print(f"Mengirim permintaan ke Oracle Cloud (Region: {region}, AD: {ad})...")

    response = compute_client.launch_instance(launch_details)
    print("🎉 SUKSES BIKIN VPS! Instance ID:", response.data.id)

except oci.exceptions.ServiceError as e:
    if e.status == 500 or "Out of host capacity" in str(e) or "Capacity" in e.message:
        print("⏳ Slot masih penuh (Out of capacity). Akan dicoba lagi pada jadwal berikutnya.")
    else:
        print("❌ OCI Service Error:", e.message)
except Exception as e:
    print("❌ Unexpected Error:", str(e))
