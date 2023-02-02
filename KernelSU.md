# Install KernelSU

1. Download pre-build kernel from [![Build WSA-5.10.117-Kernel](https://github.com/tiann/KernelSU/actions/workflows/build-WSA-5.10.117-kernel.yml/badge.svg?event=push)](https://github.com/tiann/KernelSU/actions/workflows/build-WSA-5.10.117-kernel.yml?query=branch%3Amain+event%3Apush+is%3Acompleted) (Remember to download the same architecture).

1. Download and install KernelSU Manager from [![Build Manager](https://github.com/tiann/KernelSU/actions/workflows/build-manager.yml/badge.svg?event=push)](https://github.com/tiann/KernelSU/actions/workflows/build-manager.yml?query=event%3Apush+is%3Acompleted+branch%3Amain).

1. Unzip the downloaded zip package and get the kernel file named `bzImage`.

1. Replace the kernel in the folder named `Tools` in the WSA directory with `bzImage`.

1. Restart WSA and then enjoy.
