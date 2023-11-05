rm -rf ./dist/*
zip -r ./dist/code.zip node_modules package.json ec2.js noIp.js
terraform apply -var-file env.tfvars