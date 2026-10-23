# zest :: 45-devops — módulo do Zest (extraído e testado na prática)
#  ALIASES — Docker
# ------------------------------------------------------------
alias dtop='docker stats --no-stream'
alias dinspect='docker inspect'
alias dnetwork='docker network ls'
alias dvolumes='docker volume ls'
alias dimages='docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"'
alias dclean='docker container prune -f && docker image prune -f'
alias dshell='docker run --rm -it'
alias dbuild='docker build -t'
alias dtag='docker tag'
alias dpush='docker push'

dsh() { docker exec -it "$1" /bin/bash 2>/dev/null || docker exec -it "$1" /bin/sh; }
dlogsall() { docker ps -q | xargs -L1 docker logs --tail 50; }
drmi() { docker rmi $(docker images -q "$1"); }
dbuildpush() { docker build -t "$1" . && docker push "$1"; }
dcp() { docker cp "$1:$2" "$3"; }

# ------------------------------------------------------------
#  ALIASES — Kubernetes
# ------------------------------------------------------------
alias ktop='kubectl top pods'
alias knodes='kubectl get nodes -o wide'
alias kall='kubectl get all -A'
alias kwatch='kubectl get pods -w'
alias kshell='kubectl exec -it'
alias kport='kubectl port-forward'
alias kscale='kubectl scale deployment'
alias krollout='kubectl rollout status'
alias krestart='kubectl rollout restart'
alias kctxs='kubectl config get-contexts'
alias knamespaces='kubectl get namespaces'

# ------------------------------------------------------------
#  ALIASES — Terraform
# ------------------------------------------------------------
alias tfw='terraform workspace'
alias tfws='terraform workspace select'
alias tfwl='terraform workspace list'
alias tfo='terraform output'
alias tfs='terraform state'
alias tfsl='terraform state list'
alias tfshow='terraform show'

# ------------------------------------------------------------
#  ALIASES — AWS
# ------------------------------------------------------------
alias awsec2='aws ec2 describe-instances --output table'
alias awss3='aws s3 ls'
alias awslambda='aws lambda list-functions --output table'
alias awsiam='aws iam list-users --output table'
alias awscf='aws cloudformation list-stacks --output table'
alias awslogs='aws logs tail --follow'
alias awsecr='aws ecr get-login-password | docker login --username AWS --password-stdin'

# ------------------------------------------------------------
