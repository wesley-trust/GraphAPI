# GraphAPI
Contains code for calling the Microsoft Graph API with PowerShell
## Azure AD
### Conditional Access
|  Main  | Develop |
| :----: | :-----: |
|[![Build Status](https://dev.azure.com/wesleytrust/GraphAPI/_apis/build/status/SVC-CA%3BENV-P%3B%20Conditional%20Access?branchName=main)](https://dev.azure.com/wesleytrust/GraphAPI/_build/latest?definitionId=2&branchName=main)|[![Build Status](https://dev.azure.com/wesleytrust/GraphAPI/_apis/build/status/SVC-CA%3BENV-D%3B%20Conditional%20Access?branchName=develop)](https://dev.azure.com/wesleytrust/GraphAPI/_build/latest?definitionId=5&branchName=develop)|
#### PowerShell wrapped Microsoft Graph API calls to:
- Import
- Get
- Create
- Update
- Remove
- Export
#### CI/CD Pipeline to Import, Plan and Deploy:
- Validating the input
- Evaluation the input to create a plan for approval
- Deploying to an environment, applying the plan