# Cloud Run CPU Allocation Demo

This example demonstrates the difference between **CPU allocated only during request processing** (default) and **CPU always allocated**.

## Concept

In Cloud Run, you can choose how CPU is allocated to your container instance:

1.  **CPU only during request processing (Throttled)**: The CPU is only available when the container is processing a request. Outside of requests, the CPU is throttled to nearly zero. This is cheaper but means background tasks (like a counter loop) will pause.
2.  **CPU always allocated (Always-on)**: The CPU is available for the entire lifecycle of the container instance, even when there are no incoming requests. This allows for background processing but is more expensive.

## The Demo Application

The application (`app/main.py`) starts a background thread that increments a counter every second. It also tracks the time since the last counter update.

- If the CPU is **throttled**, the background thread will pause between requests. When a new request comes in, the "Time since last background update" will be large (indicating the thread was paused).
- If the CPU is **always allocated**, the background thread will keep running. The "Time since last background update" will always be small (~1 second).

## Deployment

1.  **Deploy both services:**

    ```bash
    ./01-deploy.sh
    ```

    This script deploys two services:
    - `cpu-throttled`: Uses the default CPU allocation (throttled).
    - `cpu-always-on`: Uses the `--no-cpu-throttling` flag to keep CPU always allocated.

## Testing

1.  **Run the test script:**

    ```bash
    ./02-test.sh
    ```

    This script makes two requests to each service with a 5-second delay in between.

    **Expected Output for Throttled Service:**
    The second request will show a large "Time since last background update" (e.g., > 5 seconds), indicating the background thread was paused during the sleep period.

    **Expected Output for Always-On Service:**
    The second request will show a small "Time since last background update" (e.g., ~1 second), indicating the background thread continued to run during the sleep period.

## Cleanup

To delete the services and the container image:

```bash
./99-cleanup.sh