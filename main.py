import os
import sys
import oci

INSTANCE_NAME = "AYAH-ALMA-ARM-VPS"


def required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"Environment variable {name} belum diisi.")
    return value


try:
    user_ocid = required_env("OCI_USER_OCID")
    tenancy_ocid = required_env("OCI_TENANCY_OCID")
    region = required_env("OCI_REGION")
    subnet_id = required_env("OCI_SUBNET_ID")
    fingerprint = required_env("OCI_FINGERPRINT")
    key_content = required_env("OCI_KEY_FILE")
    ssh_public_key = required_env("OCI_SSH_PUBLIC_KEY")

    config = {
        "user": user_ocid,
        "key_content": key_content,
        "fingerprint": fingerprint,
        "tenancy": tenancy_ocid,
        "region": region,
    }

    compute_client = oci.core.ComputeClient(config)
    identity_client = oci.identity.IdentityClient(config)

    # Hindari meluncurkan VM baru setiap kali skrip ini dijalankan ulang.
    existing = compute_client.list_instances(
        compartment_id=tenancy_ocid,
        display_name=INSTANCE_NAME,
    ).data
    active_existing = [instance for instance in existing if instance.lifecycle_state != "TERMINATED"]
    if active_existing:
        print(
            "Instance dengan nama yang sama sudah ada; tidak membuat duplikat. "
            f"ID={active_existing[0].id}, state={active_existing[0].lifecycle_state}"
        )
        sys.exit(0)

    availability_domains = identity_client.list_availability_domains(tenancy_ocid).data
    if not availability_domains:
        raise RuntimeError("Oracle Cloud tidak mengembalikan Availability Domain.")
    availability_domain = availability_domains[0].name

    shape = "VM.Standard.A1.Flex"
    ocpus = 4
    memory_in_gbs = 24

    # setup.sh hanya mendukung Ubuntu/Debian; pilih Ubuntu ARM agar VM hasil
    # kompatibel dengan installer proyek.
    images = compute_client.list_images(
        compartment_id=tenancy_ocid,
        operating_system="Canonical Ubuntu",
        operating_system_version="22.04",
    ).data
    if not images:
        images = compute_client.list_images(
            compartment_id=tenancy_ocid,
            operating_system="Canonical Ubuntu",
        ).data
    if not images:
        raise RuntimeError("Tidak ditemukan image Canonical Ubuntu yang kompatibel dengan setup.sh.")

    # Pilih image terbaru yang tersedia, bukan bergantung pada urutan respons API.
    images.sort(key=lambda image: image.time_created.timestamp() if image.time_created else 0, reverse=True)
    image_id = images[0].id

    launch_details = oci.core.models.LaunchInstanceDetails(
        compartment_id=tenancy_ocid,
        availability_domain=availability_domain,
        shape=shape,
        shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
            ocpus=ocpus,
            memory_in_gbs=memory_in_gbs,
        ),
        create_vnic_details=oci.core.models.CreateVnicDetails(
            subnet_id=subnet_id,
            assign_public_ip=True,
        ),
        source_details=oci.core.models.InstanceSourceViaImageDetails(image_id=image_id),
        metadata={"ssh_authorized_keys": ssh_public_key},
        display_name=INSTANCE_NAME,
    )

    print(f"Mengirim permintaan ke Oracle Cloud (Region: {region}, AD: {availability_domain})...")
    response = compute_client.launch_instance(launch_details)
    print(f"Permintaan pembuatan instance berhasil. Instance ID: {response.data.id}")

except oci.exceptions.ServiceError as exc:
    message = getattr(exc, "message", str(exc))
    if exc.status == 500 or "Out of host capacity" in str(exc) or "Capacity" in message:
        print("Slot kapasitas belum tersedia. Coba lagi nanti setelah kapasitas tersedia.")
    else:
        print(f"OCI Service Error (HTTP {exc.status}): {message}", file=sys.stderr)
        sys.exit(1)
except (ValueError, RuntimeError) as exc:
    print(f"Konfigurasi/error: {exc}", file=sys.stderr)
    sys.exit(1)
except Exception as exc:
    print(f"Unexpected Error: {exc}", file=sys.stderr)
    sys.exit(1)
