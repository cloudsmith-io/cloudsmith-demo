# Cloudsmith Handy Scripts 🛠️

A collection of **bash scripts** to help automate common tasks in **Cloudsmith**:

✅ **Monitor package statuses**  
✅ **Check dependencies for vulnerabilities**  
✅ **Automate security scans**  
✅ **Verify quarantined packages**  

## 📌 Prerequisites  
Before using these scripts, ensure you have:

- **A Cloudsmith API key** (see: [API Docs](https://api.cloudsmith.io/v1/))  
- **`jq` installed** for JSON parsing (`sudo apt install jq` on Ubuntu, `brew install jq` on macOS)  

---

## 🚀 Available Scripts  

### **1️⃣ Check Maven Package Dependencies**  
📌 **File:** [`check_cloudsmith_maven.sh`](check_cloudsmith_maven.sh)  
🔍 **Purpose:** Checks if a Maven package **or its dependencies** have vulnerabilities in Cloudsmith.  

#### **Usage:**  
```bash
./check_cloudsmith_maven.sh <ORG> <REPO> <API_KEY> <PACKAGE_NAME> [<PACKAGE_VERSION>]
```
#### **Example:**  
```bash
./check_cloudsmith_maven.sh ciara-demo acme-nonprod MY-API-KEY my-app 1.0-SNAPSHOT
```
- Finds the package in Cloudsmith  
- Checks if it is **quarantined or has security vulnerabilities**  
- Fetches dependencies and verifies them  

---

### **2️⃣ Check Docker Image Status**  
📌 **File:** [`check_cloudsmith_docker.sh`](check_cloudsmith_docker.sh)  
🔍 **Purpose:** **Monitors the status** of a **Docker image** in Cloudsmith, checking for **sync completion and vulnerabilities**.  

#### **Usage:**  
```bash
./check_cloudsmith_docker.sh <ORG> <REPO> <API_KEY> <IMAGE_TAG>
```
#### **Example:**  
```bash
./check_cloudsmith_docker.sh my-org my-repo my-api-key docker.cloudsmith.io/my-org/my-repo/my-image:latest
```
- Checks if the **Docker image exists**  
- Waits for **sync to complete**  
- Flags if the image is **quarantined or vulnerable**  

---

## 📥 Contributing  
Got a useful Cloudsmith script? **Submit a PR!** 🚀  

---

## 📚 More Cloudsmith Resources  
- **API Docs:** [Cloudsmith API Reference](https://api.cloudsmith.io/v1/)  
- **CLI Tool:** [Cloudsmith CLI](https://help.cloudsmith.io/docs/cloudsmith-cli)  

