#!/bin/bash

# Configure Keycloak realm and clients for all services
# This script automates the Keycloak configuration via REST API

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
KEYCLOAK_URL="http://localhost:8090"
ADMIN_USER="admin"
ADMIN_PASS="admin123"
REALM_NAME="k8s-stack"
JENKINS_CLIENT_ID="jenkins"
JENKINS_CLIENT_SECRET="jenkins-secret"
N8N_CLIENT_ID="n8n"
N8N_CLIENT_SECRET="n8n-secret"
POSTGRES_CLIENT_ID="postgres-admin"
POSTGRES_CLIENT_SECRET="postgres-secret"

USER_USERNAME="jmiguelmangas"
USER_PASSWORD="leicakanon2025"
USER_EMAIL="jmiguelmangas@example.com"
USER_FIRST_NAME="Jose Miguel"
USER_LAST_NAME="Mangas"

print_status "Starting Keycloak configuration..."

# Wait for Keycloak to be ready
print_status "Waiting for Keycloak to be ready..."
for i in {1..30}; do
    if curl -s -f "$KEYCLOAK_URL/realms/master" > /dev/null; then
        print_success "Keycloak is ready!"
        break
    fi
    echo -n "."
    sleep 10
done

if ! curl -s -f "$KEYCLOAK_URL/realms/master" > /dev/null; then
    print_error "Keycloak is not accessible at $KEYCLOAK_URL"
    print_error "Please ensure Keycloak is running and port-forwarded to 8090"
    exit 1
fi

# Get admin access token
print_status "Getting admin access token..."
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    print_error "Failed to get admin access token"
    exit 1
fi

print_success "Admin access token obtained"

# Create realm
print_status "Creating realm '$REALM_NAME'..."
REALM_DATA='{
  "realm": "'$REALM_NAME'",
  "displayName": "K8s Stack Realm",
  "enabled": true,
  "registrationAllowed": false,
  "rememberMe": true,
  "verifyEmail": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": true
}'

REALM_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$REALM_DATA")

REALM_HTTP_CODE="${REALM_RESPONSE: -3}"
if [ "$REALM_HTTP_CODE" = "201" ] || [ "$REALM_HTTP_CODE" = "409" ]; then
    print_success "Realm '$REALM_NAME' created or already exists"
else
    print_error "Failed to create realm. HTTP code: $REALM_HTTP_CODE"
    exit 1
fi

# Create roles
print_status "Creating realm roles..."
ROLES=("admin" "developer" "viewer")

for role in "${ROLES[@]}"; do
    ROLE_DATA='{
      "name": "'$role'",
      "description": "'$role' role for all services"
    }'
    
    ROLE_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/roles" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$ROLE_DATA")
    
    ROLE_HTTP_CODE="${ROLE_RESPONSE: -3}"
    if [ "$ROLE_HTTP_CODE" = "201" ] || [ "$ROLE_HTTP_CODE" = "409" ]; then
        print_success "Role '$role' created or already exists"
    fi
done

# Create groups
print_status "Creating groups..."
GROUPS=("jenkins-admins" "jenkins-developers" "jenkins-viewers" "n8n-admins" "postgres-admins")

for group in "${GROUPS[@]}"; do
    GROUP_DATA='{
      "name": "'$group'",
      "path": "/'$group'"
    }'
    
    GROUP_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/groups" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$GROUP_DATA")
    
    GROUP_HTTP_CODE="${GROUP_RESPONSE: -3}"
    if [ "$GROUP_HTTP_CODE" = "201" ] || [ "$GROUP_HTTP_CODE" = "409" ]; then
        print_success "Group '$group' created or already exists"
    fi
done

# Create Jenkins client
print_status "Creating Jenkins OIDC client..."
JENKINS_CLIENT_DATA='{
  "clientId": "'$JENKINS_CLIENT_ID'",
  "name": "Jenkins CI/CD",
  "description": "Jenkins continuous integration server",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "'$JENKINS_CLIENT_SECRET'",
  "redirectUris": [
    "http://jenkins.local:8080/securityRealm/finishLogin",
    "http://localhost:8081/securityRealm/finishLogin"
  ],
  "webOrigins": [
    "http://jenkins.local:8080",
    "http://localhost:8081"
  ],
  "protocol": "openid-connect",
  "fullScopeAllowed": true,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": false,
  "publicClient": false,
  "protocolMappers": [
    {
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "consentRequired": false,
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "groups",
        "userinfo.token.claim": "true"
      }
    }
  ]
}'

JENKINS_CLIENT_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JENKINS_CLIENT_DATA")

JENKINS_CLIENT_HTTP_CODE="${JENKINS_CLIENT_RESPONSE: -3}"
if [ "$JENKINS_CLIENT_HTTP_CODE" = "201" ] || [ "$JENKINS_CLIENT_HTTP_CODE" = "409" ]; then
    print_success "Jenkins client created or already exists"
else
    print_error "Failed to create Jenkins client. HTTP code: $JENKINS_CLIENT_HTTP_CODE"
fi

# Create N8N client
print_status "Creating N8N OIDC client..."
N8N_CLIENT_DATA='{
  "clientId": "n8n",
  "name": "N8N Workflow Automation",
  "description": "N8N workflow automation platform",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "n8n-secret",
  "redirectUris": [
    "http://n8n.local:5678/rest/oauth2-credential/callback",
    "http://localhost:5678/rest/oauth2-credential/callback"
  ],
  "webOrigins": [
    "http://n8n.local:5678",
    "http://localhost:5678"
  ],
  "protocol": "openid-connect",
  "fullScopeAllowed": true,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": false,
  "publicClient": false,
  "protocolMappers": [
    {
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "consentRequired": false,
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "groups",
        "userinfo.token.claim": "true"
      }
    }
  ]
}'

N8N_CLIENT_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$N8N_CLIENT_DATA")

N8N_CLIENT_HTTP_CODE="${N8N_CLIENT_RESPONSE: -3}"
if [ "$N8N_CLIENT_HTTP_CODE" = "201" ] || [ "$N8N_CLIENT_HTTP_CODE" = "409" ]; then
    print_success "N8N client created or already exists"
else
    print_error "Failed to create N8N client. HTTP code: $N8N_CLIENT_HTTP_CODE"
fi

# Create PostgreSQL client (for pgAdmin integration)
print_status "Creating PostgreSQL OIDC client..."
POSTGRESQL_CLIENT_DATA='{
  "clientId": "postgresql",
  "name": "PostgreSQL Database",
  "description": "PostgreSQL database access",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "postgresql-secret",
  "redirectUris": [
    "http://postgresql.local:5432/oauth2/callback",
    "http://localhost:5432/oauth2/callback"
  ],
  "webOrigins": [
    "http://postgresql.local:5432",
    "http://localhost:5432"
  ],
  "protocol": "openid-connect",
  "fullScopeAllowed": true,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": false,
  "publicClient": false,
  "protocolMappers": [
    {
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "consentRequired": false,
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "groups",
        "userinfo.token.claim": "true"
      }
    }
  ]
}'

POSTGRESQL_CLIENT_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$POSTGRESQL_CLIENT_DATA")

POSTGRESQL_CLIENT_HTTP_CODE="${POSTGRESQL_CLIENT_RESPONSE: -3}"
if [ "$POSTGRESQL_CLIENT_HTTP_CODE" = "201" ] || [ "$POSTGRESQL_CLIENT_HTTP_CODE" = "409" ]; then
    print_success "PostgreSQL client created or already exists"
else
    print_error "Failed to create PostgreSQL client. HTTP code: $POSTGRESQL_CLIENT_HTTP_CODE"
fi

# Create admin user
print_status "Creating admin user '$USER_USERNAME'..."
USER_DATA='{
  "username": "'$USER_USERNAME'",
  "email": "'$USER_EMAIL'",
  "firstName": "'$USER_FIRST_NAME'",
  "lastName": "'$USER_LAST_NAME'",
  "enabled": true,
  "emailVerified": true,
  "credentials": [
    {
      "type": "password",
      "value": "'$USER_PASSWORD'",
      "temporary": false
    }
  ]
}'

USER_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$USER_DATA")

USER_HTTP_CODE="${USER_RESPONSE: -3}"
if [ "$USER_HTTP_CODE" = "201" ] || [ "$USER_HTTP_CODE" = "409" ]; then
    print_success "User '$USER_USERNAME' created or already exists"
else
    print_error "Failed to create user. HTTP code: $USER_HTTP_CODE"
fi

# Get user ID for group assignment
print_status "Getting user ID for group assignment..."
USER_ID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users?username=$USER_USERNAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')

if [ "$USER_ID" != "null" ] && [ -n "$USER_ID" ]; then
    print_success "User ID obtained: $USER_ID"
    
    # Get group IDs and assign user to admin groups
    print_status "Assigning user to admin groups..."
    ADMIN_GROUPS=("jenkins-admins" "n8n-admins" "postgres-admins")
    
    for group_name in "${ADMIN_GROUPS[@]}"; do
        GROUP_ID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/groups?search=$group_name" \
          -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')
        
        if [ "$GROUP_ID" != "null" ] && [ -n "$GROUP_ID" ]; then
            GROUP_ASSIGN_RESPONSE=$(curl -s -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users/$USER_ID/groups/$GROUP_ID" \
              -H "Authorization: Bearer $ADMIN_TOKEN")
            
            GROUP_ASSIGN_HTTP_CODE="${GROUP_ASSIGN_RESPONSE: -3}"
            if [ "$GROUP_ASSIGN_HTTP_CODE" = "204" ]; then
                print_success "User assigned to group '$group_name'"
            fi
        fi
    done
fi

print_success "Keycloak configuration completed!"
echo ""
echo "=================== KEYCLOAK CONFIGURATION SUMMARY ==================="
echo ""
echo "Keycloak Admin Console: $KEYCLOAK_URL"
echo "Admin Username: $ADMIN_USER"
echo "Admin Password: $ADMIN_PASS"
echo ""
echo "Realm: $REALM_NAME"
echo "User: $USER_USERNAME"
echo "Password: $USER_PASSWORD"
echo ""
echo "Jenkins Client:"
echo "  Client ID: $JENKINS_CLIENT_ID"
echo "  Client Secret: $JENKINS_CLIENT_SECRET"
echo ""
echo "N8N Client:"
echo "  Client ID: n8n"
echo "  Client Secret: n8n-secret"
echo ""
echo "PostgreSQL Client:"
echo "  Client ID: postgresql"
echo "  Client Secret: postgresql-secret"
echo ""
echo "Groups created:"
echo "  - jenkins-admins (user assigned)"
echo "  - jenkins-developers"
echo "  - jenkins-viewers"
echo "  - n8n-admins (user assigned)"
echo "  - postgres-admins (user assigned)"
echo ""
print_success "You can now start Jenkins and other services with Keycloak authentication!"
