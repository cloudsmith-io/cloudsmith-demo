# Cloudsmith EPM Rego Policy Examples

Cloudsmith's **Enterprise Policy Manager (EPM)** is built on **Open Policy Agent (OPA)** and helps control package flow within your organization, ensuring only **compliant and secure artifacts** make it into production.

## 📌 Quick Links

- [EPM API Reference](https://api.cloudsmith.io/v2/redoc/)
- [EPM Documentation](https://help.cloudsmith.io/docs/enterprise-policy-management)

## 🛠️ Understanding Rego vs. API Execution

### Rego Policies (Code in This Repository)

✅ Define **what conditions trigger a policy**  
✅ Specify **match criteria** (e.g., CVSS score, package tags, repo name)  
✅ Output **reasons for a match**  

### Cloudsmith API/UI (Execution & Management)

✅ **Create the policy** (via API/UI)  
✅ **Attach actions** (e.g., quarantine, tagging)  
✅ **Simulate policies** before enabling them  
✅ **Monitor decision logs**  
✅ **Enable/disable policies** as needed  

📌 **Important:** The Rego policy itself **only defines the conditions for triggering a policy**. The **actual enforcement actions** (such as quarantining, tagging, or blocking) are **configured separately** in the Cloudsmith API/UI.

---

## 📜 Rego Policy Requirements

Every Rego policy in Cloudsmith **must** include:

```rego
package cloudsmith  # Required for Cloudsmith EPM policies
```

**Optional But Recommended:**
```rego
import rego.v1  # Required for using Rego v1-specific functions
```

* If your policy includes functions like contains() or set operations, you must include import rego.v1.
* If you only use basic conditions, the import is optional.

