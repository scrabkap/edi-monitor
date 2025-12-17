# EDI Monitor - AWS Region Configuration

This project is configured to deploy to **eu-west-1 (Europe - Ireland)**.

Make sure your GitHub Secrets include:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION=eu-west-1`

All resources (S3, Lambda, API Gateway, CloudFront) will be created in eu-west-1.
