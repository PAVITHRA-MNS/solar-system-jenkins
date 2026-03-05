**End-to-End DevSecOps CI/CD Pipeline with Branch-Based Deployments**

I built a **complete DevSecOps CI/CD pipeline using Jenkins** for a Node.js application that automates testing, security scanning, containerization, and multi-environment deployments.

The pipeline follows a **branch-based deployment strategy** using Jenkins `when` conditions:

🔹 **Feature Branch (`feature/*`)**
When code is pushed to a feature branch, the pipeline builds the application, runs tests, creates a Docker image, and **deploys it to a development VM using SSH and Docker**. After deployment, **integration tests are executed on the VM** to verify the application in a real runtime environment.

🔹 **Pull Request (`PR*`)**
When a Pull Request is created, the pipeline updates the **Kubernetes deployment manifest in a GitOps repository** with the new Docker image tag and automatically raises a PR. After approval and **ArgoCD sync**, the application is deployed to the **Kubernetes cluster**. A **DAST security scan using OWASP ZAP** is also performed to identify runtime vulnerabilities.

🔹 **Main Branch (`main`)**
Once the PR is merged into the main branch, the pipeline packages the application for **serverless deployment**. The code is zipped, uploaded to **Amazon S3**, and deployed as an **AWS Lambda function**, followed by a test invocation to verify the deployment.

This approach ensures **progressive delivery across environments — Development VM → Kubernetes → Serverless deployment**.

---

### 🛠 Tools & Technologies Used

• Jenkins – CI/CD pipeline orchestration
• Node.js & NPM – Application runtime and dependency management
• Docker – Containerization
• Docker Registry – Image storage
• Trivy – Container vulnerability scanning
• OWASP ZAP – Dynamic application security testing (DAST)
• Git / Gitea – Source code and GitOps repository
• SSH – Remote VM deployment
• Kubernetes – Container orchestration
• ArgoCD – GitOps continuous delivery
• AWS S3 – Artifact storage
• AWS Lambda – Serverless deployment
• LocalStack – Local AWS service simulation
• Bash – Integration testing scripts

This project demonstrates how **CI/CD, DevSecOps practices, GitOps workflows, container security, Kubernetes deployments, and serverless architectures** can be integrated into a single automated pipeline.

