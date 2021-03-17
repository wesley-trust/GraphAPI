# GraphAPI
Contains code for calling the Microsoft Graph API with PowerShell
## Azure AD
| Service |  Main  | Develop |
|:---| :----: | :-----: |
| Conditional Access |[![Build Status](https://dev.azure.com/wesleytrust/GraphAPI/_apis/build/status/SVC-CA%3BENV-P%3B%20Conditional%20Access?branchName=main)](https://dev.azure.com/wesleytrust/GraphAPI/_build/latest?definitionId=2&branchName=main)|[![Build Status](https://dev.azure.com/wesleytrust/GraphAPI/_apis/build/status/SVC-CA%3BENV-D%3B%20Conditional%20Access?branchName=develop)](https://dev.azure.com/wesleytrust/GraphAPI/_build/latest?definitionId=5&branchName=develop)|
| Groups |[![Build Status](https://dev.azure.com/wesleytrust/GraphAPI/_apis/build/status/SVC-CA%3BENV-P%3B%20Groups?branchName=main)](https://dev.azure.com/wesleytrust/GraphAPI/_build/latest?definitionId=9&branchName=main)|[![Build Status](https://dev.azure.com/wesleytrust/GraphAPI/_apis/build/status/SVC-CA%3BENV-D%3B%20Groups?branchName=develop)](https://dev.azure.com/wesleytrust/GraphAPI/_build/latest?definitionId=7&branchName=develop)|
### PowerShell wrapped Microsoft Graph API calls to:
- Import
- Get
- Create
- Update
- Remove
- Export
### CI/CD Pipeline to Import, Plan and Deploy:
- Validating the input against set criteria
- Evaluating the input against what is deployed, to create a change plan for approval
- Deploying to a specified environment, applying the approved plan