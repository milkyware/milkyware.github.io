---
title: Importing AzureAD App Role Assignments to Terraform
category: Terraform
tags:
  - Terraform
  - Azure
  - Azure AD
  - Entra
  - App Role Assignments
---

## Summary of AzureAD App Role Assignment ID Format Differences

### **1. Old Format** (`azuread` provider < v2.0.0)

```
<principal_object_id>/appRoleAssignment/<app_role_assignment_id>
```

**Explanation of Sections:**

- `principal_object_id`: The Object ID of the user, group, or service principal receiving the app role assignment.
- `appRoleAssignment`: A fixed string indicating the resource type.
- `app_role_assignment_id`: A unique identifier for the app role assignment.

**How to Obtain Values (Old Format):**

- `principal_object_id`:
  ```bash
  az ad group show --group "<group-name>" --query "id" -o tsv
  ```
- `app_role_assignment_id`: Could only be retrieved indirectly (not always exposed in older CLI tools).

---

### **2. New Format** (`azuread` provider ≥ v2.0.0 or testing builds)
```
/servicePrincipals/<app_registration_object_id>/appRoleAssignedTo/<assignment_id>
```

**Explanation of Sections:**
- `/servicePrincipals`: Prefix that indicates the app role assignment is associated with a service principal (application) in Azure AD.
- `app_registration_object_id`: The Object ID of the **service principal** providing the app role.
- `appRoleAssignedTo`: The path segment indicating the app role assignments in Microsoft Graph.
- `assignment_id`: The unique identifier for the specific app role assignment.

**How to Obtain Values (New Format):**
1. **App Registration Object ID** (Service Principal):
   ```bash
   az ad sp show --id "<application-id>" --query "id" -o tsv
   ```
2. **App Role Assignment ID**:
   List app role assignments for the service principal:
   ```bash
   az rest --method GET \
     --url "https://graph.microsoft.com/v1.0/servicePrincipals/<app_registration_object_id>/appRoleAssignedTo"
   ```
   Extract `id` from the response for the specific assignment.

---

## Key Differences Between Old and New Formats
- **Resource Representation**:  
  The old format used the `principal_object_id` as the leading identifier, while the new format is **app registration-centric**, reflecting the **Microsoft Graph API** structure.
- **Resource Path**:  
  The old format used a type (`appRoleAssignment`) inline, whereas the new format explicitly defines the relationship (`appRoleAssignedTo`) in the path with the `/servicePrincipals` prefix.
- **Assignment ID Source**:  
  The new format explicitly uses `id` from the Microsoft Graph API response.

---

## Impacted Terraform Versions
- **Old Format**: Used by `azuread` provider versions **< v2.0.0**.
- **New Format**: Introduced in **v2.0.0+**, which aligns with the transition to the **Microsoft Graph API** backend. Testing builds or pre-releases may also enforce this change.

---

## Migration Recommendations
1. Identify the Terraform provider version:
   ```bash
   terraform providers
   ```
2. Update the state to match the new format:
   - Use `terraform state mv` or re-import resources using the new ID format.
3. Upgrade to the latest `azuread` provider version and test in a non-production environment.

---

Let me know if you need further adjustments or additional details!