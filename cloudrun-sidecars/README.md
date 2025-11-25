# Cloud Run Sidecar Demo

This example demonstrates how to deploy a Cloud Run service with multiple containers (sidecars).

## Architecture

The service consists of two containers running in the same instance:

1.  **main-app**: A Python Flask application that serves the public traffic on port 8080. It makes a request to the sidecar container on `localhost`.
2.  **sidecar**: A Python Flask application running on port 8081. It is not accessible from the public internet, only from within the instance (by the main app).

## Prerequisites

- Google Cloud Project with Cloud Run and Container Registry/Artifact Registry enabled.
- `gcloud` CLI installed and configured.

## Deployment Steps

1.  **Build the container images:**

    ```bash
    ./01-build.sh
    ```

    This script builds both the `main-app` and `sidecar` images and pushes them to Google Container Registry (GCR).

2.  **Deploy the service:**

    ```bash
    ./02-deploy.sh
    ```

    This script replaces the `PROJECT_ID` placeholder in `service.yaml` and deploys the multi-container service to Cloud Run. It also configures the service to allow unauthenticated access for demonstration purposes.

## Testing

After deployment, access the URL provided by Cloud Run. You should see a web page that clearly demonstrates the communication between the containers.

The output will look something like this:

> **Cloud Run Sidecar Demo**
>
> This is the **Main Application** container running on port 8080.
>
> I attempted to contact the **Sidecar** container on `http://localhost:8081`.
>
> **Result: SUCCESS**
>
> **Sidecar Response:** I am the sidecar container!

This confirms that the main application was able to reach the sidecar container over `localhost`.

## Cleanup

To delete the Cloud Run service and the container images:

```bash
./99-cleanup.sh