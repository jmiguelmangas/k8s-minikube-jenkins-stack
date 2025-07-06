# Keycloak Setup Guide

This guide walks you through configuring Keycloak as a centralized identity provider for the Kubernetes stack.

## Overview

Keycloak provides centralized authentication for:
- ✅ Jenkins (via OIDC plugin)
- 🔄 N8N (requires additional configuration)
- 🔄 PostgreSQL (via authentication proxy or application-level integration)

## Prerequisites

- Keycloak deployed and accessible
- Admin credentials: `admin` / `admin123`

## Step 1: Access Keycloak Admin Console

1. Start port-forwarding:
   ```bash
   kubectl port-forward svc/keycloak 8090:8080 -n keycloak
   ```

2. Open browser and navigate to: http://localhost:8090

3. Login with admin credentials:
   - Username: `admin`
   - Password: `admin123`

## Step 2: Create Realm

1. Click on the dropdown next to "Master" in the top left
2. Click "Create Realm"
3. Set realm name: `k8s-stack`
4. Click "Create"

## Step 3: Configure Jenkins OIDC Client

### Create Jenkins Client

1. In the `k8s-stack` realm, go to "Clients"
2. Click "Create client"
3. Fill in the details:
   - **Client type**: OpenID Connect
   - **Client ID**: `jenkins`
   - Click "Next"

4. Configure client settings:
   - **Client authentication**: ON
   - **Authorization**: OFF
   - **Authentication flow**: Standard flow, Direct access grants
   - Click "Next"

5. Set login settings:
   - **Root URL**: `http://jenkins.local:8080`
   - **Home URL**: `http://jenkins.local:8080`
   - **Valid redirect URIs**: `http://jenkins.local:8080/securityRealm/finishLogin`
   - **Valid post logout redirect URIs**: `http://jenkins.local:8080`
   - **Web origins**: `http://jenkins.local:8080`
   - Click "Save"

### Get Client Secret

1. Go to "Clients" → "jenkins"
2. Click on "Credentials" tab
3. Copy the "Client secret" value
4. Update the Kubernetes secret:
   ```bash
   kubectl patch secret jenkins-oidc-secret -n jenkins -p='{"data":{"CLIENT_SECRET":"'$(echo -n "YOUR_CLIENT_SECRET" | base64)'"}}'
   ```

## Step 4: Create Users and Groups

### Create Groups

1. Go to "Groups"
2. Create the following groups:
   - `jenkins-admins` (for Jenkins administrators)
   - `jenkins-developers` (for Jenkins developers)
   - `jenkins-viewers` (for Jenkins viewers)

### Create Users

1. Go to "Users"
2. Click "Create new user"
3. Fill in user details:
   - **Username**: Choose a username
   - **Email**: User's email
   - **First name**: User's first name
   - **Last name**: User's last name
   - **Email verified**: ON
   - **Enabled**: ON

4. Click "Create"

### Set User Password

1. Go to the user → "Credentials" tab
2. Click "Set password"
3. Enter password (uncheck "Temporary" for permanent password)
4. Click "Save password"

### Assign User to Groups

1. Go to the user → "Groups" tab
2. Select appropriate group (e.g., `jenkins-admins`)
3. Click "Join"

## Step 5: Configure Group Mappings

### Add Group Mapper

1. Go to "Clients" → "jenkins"
2. Click "Client scopes" tab
3. Click "jenkins-dedicated"
4. Click "Mappers" tab
5. Click "Add mapper" → "By configuration"
6. Select "Group Membership"
7. Configure the mapper:
   - **Name**: `groups`
   - **Token Claim Name**: `groups`
   - **Full group path**: OFF
   - **Add to ID token**: ON
   - **Add to access token**: ON
   - **Add to userinfo**: ON
8. Click "Save"

## Step 6: Test Configuration

### Test Jenkins Login

1. Start Jenkins port-forward:
   ```bash
   kubectl port-forward svc/jenkins-service 8081:8080 -n jenkins
   ```

2. Navigate to: http://localhost:8081

3. You should see "Login with OpenID Connect" option

4. Click it and login with Keycloak credentials

### Emergency Access

If OIDC login fails, use the escape hatch:
- Username: `admin`
- Password: `admin123`
- Login URL: http://localhost:8081/login

## Step 7: Advanced Configuration

### Configure N8N Integration (Optional)

N8N doesn't have built-in OIDC support, but can be integrated via:

1. **OAuth2 Proxy**: Deploy an OAuth2 proxy in front of N8N
2. **Custom Authentication**: Use N8N's webhook authentication with Keycloak

### Example OAuth2 Proxy for N8N:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: n8n
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:latest
        args:
        - --provider=oidc
        - --oidc-issuer-url=http://keycloak.keycloak.svc.cluster.local:8080/realms/k8s-stack
        - --client-id=n8n
        - --client-secret=n8n-secret
        - --cookie-secret=CHANGE_ME_16_CHARS
        - --email-domain=*
        - --upstream=http://n8n-service.n8n.svc.cluster.local:80
        - --http-address=0.0.0.0:4180
        ports:
        - containerPort: 4180
```

## Troubleshooting

### Common Issues

1. **OIDC Configuration Error**:
   - Verify client secret matches in both Keycloak and Kubernetes
   - Check redirect URIs are correctly configured
   - Ensure realm name is `k8s-stack`

2. **User Cannot Login**:
   - Verify user is enabled in Keycloak
   - Check user is assigned to appropriate group
   - Verify group mapper is configured

3. **Jenkins Shows "Access Denied"**:
   - Check role-based authorization in Jenkins
   - Verify group names match Jenkins configuration
   - Ensure user is in correct group

### Verification Commands

```bash
# Check Jenkins OIDC configuration
kubectl get configmap jenkins-oidc-config -n jenkins -o yaml

# Check Jenkins OIDC secret
kubectl get secret jenkins-oidc-secret -n jenkins -o yaml

# Check Keycloak logs
kubectl logs -f deployment/keycloak -n keycloak

# Check Jenkins logs
kubectl logs -f deployment/jenkins-deployment -n jenkins
```

## Security Considerations

1. **Change Default Passwords**: Always change default admin passwords
2. **Use HTTPS**: In production, configure TLS for all services
3. **Network Policies**: Implement network policies to restrict traffic
4. **Secret Management**: Use external secret management (e.g., Vault)
5. **Regular Updates**: Keep Keycloak and all components updated

## Realm Export/Import

### Export Realm Configuration

```bash
kubectl exec -it deployment/keycloak -n keycloak -- \
  /opt/keycloak/bin/kc.sh export \
  --realm k8s-stack \
  --file /tmp/k8s-stack-realm.json

kubectl cp keycloak/$(kubectl get pods -n keycloak -l app=keycloak -o jsonpath='{.items[0].metadata.name}'):/tmp/k8s-stack-realm.json ./k8s-stack-realm.json
```

### Import Realm Configuration

```bash
kubectl cp ./k8s-stack-realm.json keycloak/$(kubectl get pods -n keycloak -l app=keycloak -o jsonpath='{.items[0].metadata.name}'):/tmp/k8s-stack-realm.json

kubectl exec -it deployment/keycloak -n keycloak -- \
  /opt/keycloak/bin/kc.sh import \
  --file /tmp/k8s-stack-realm.json
```

## Next Steps

1. Configure additional applications for OIDC authentication
2. Set up SSO for development tools
3. Implement fine-grained authorization policies
4. Configure audit logging
5. Set up backup and disaster recovery for Keycloak data
