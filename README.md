# IETF Source-Selective BGP Extensions

This repository contains the source code, version history, and automation tools for the active development of the IETF Internet-Drafts regarding **Source-Selective BGP Routing**. These documents define architectural frameworks and BGP path attribute extensions designed to enforce Source Address Validation (SAV), optimize routing security, and proactively mitigate high-volume distributed denial-of-service (DDoS) threats.

## Tracked Internet-Drafts

This mono-repo actively manages two closely coupled documents inside their respective directories:

*   **`bgp-source-selective-attr/`**  
    Contains `draft-braet-idr-bgp-source-selective-attr`. This document specifies the encoding, semantics, and operational procedures for the new BGP `SOURCE_SELECTIVE` Path Attribute, introducing mechanisms like the Max AS Hops sub-TLV and policy enforcement guidelines for ASBR nodes.
*   **`source-selective-bgp-framework/`**  
    Contains `draft-braet-idr-source-selective-bgp-framework`. This document establishes the broader architectural framework, evaluating scalability traits against FlowSpec, outlining diagnostic interactions (such as path MTU discovery handling), and explaining why standard BGP Community signaling is omitted.

---

## Live Inline Previews (GitHub Pages)

Every time updates are pushed to the `main` branch, an automated GitHub Actions pipeline compiles the source files using `kramdown-rfc2629` and `xml2rfc`. You can view the live drafts directly in your browser:

*   **Landing Page Menu:** [kabraet.github.io/ietf-source-selective-bgp/](https://github.io)
*   **BGP Attribute Draft:** [HTML Version](https://github.ioattr.html) | [Plain Text Version](https://github.ioattr.txt)
*   **Framework Draft:** [HTML Version](https://github.ioframework.html) | [Plain Text Version](https://github.ioframework.txt)

---

## Local Development & Compilation

The drafts are written in the IETF-compliant **Markdown (`kramdown-rfc`)** dialect. 

### Prerequisites
To compile these documents locally inside WSL Ubuntu, ensure you have the required dependencies installed:
```bash
sudo apt update
sudo apt install ruby-full python3-pip python3-venv build-essential -y
sudo gem install kramdown-rfc
pip3 install xml2rfc
```

### Build Shortcuts
A unified local `Makefile` handles the compilation lifecycle:

*   **Compile all formats** (Outputs local `.xml`, `.html`, and `.txt` files alongside the sources):
    ```bash
    make
    ```
*   **Compile text/HTML exclusively**:
    ```bash
    make txt
    make html
    ```
*   **Wipe all local build artifacts** (Cleans the workspace, keeping only source markdown text):
    ```bash
    make clean
    ```

---

## Version Control Rules

To maintain historical clarity matching standard IETF Working Group practices:
1.  **Do not commit build targets** (`.txt`, `.html`, `.xml`). They are explicitly filtered via `.gitignore` to avoid version-control bloat.
2.  **Archive historical milestones.** Finalized versions (such as the base `-00` draft string) are kept static inside the local `archive/` subfolders for long-term audit tracking.

