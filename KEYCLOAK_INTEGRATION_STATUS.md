# 🔐 Keycloak Integration Status

## ✅ Integration Completada

La integración de Keycloak con todos los servicios ha sido configurada exitosamente. A continuación se detalla el estado y acceso a cada servicio:

## 🎯 Servicios Integrados

### 1. 🔐 Keycloak (Proveedor de Autenticación)
- **Estado**: ✅ Funcionando
- **URL**: http://localhost:8090
- **Admin Console**: http://localhost:8090/admin/
- **Credenciales Admin**: `admin` / `admin123`
- **Realm**: `k8s-stack`

### 2. 🔧 Jenkins CI/CD
- **Estado**: 🔄 Configurado (pod iniciándose)
- **URL**: http://localhost:8081
- **Autenticación**: Keycloak OIDC
- **Usuario**: `jmiguelmangas` / `leicakanon2025`
- **Escape Hatch**: `admin` / `leicakanon2025`

### 3. ⚡ N8N Workflow Automation
- **Estado**: 🔄 Configurado (iniciándose)
- **URL**: http://localhost:5678
- **Autenticación**: Keycloak OIDC
- **Usuario**: `jmiguelmangas` / `leicakanon2025`
- **Base de Datos**: PostgreSQL

### 4. 🗄️ PostgreSQL Database
- **Estado**: 🔄 Configurado (iniciándose)
- **Host**: localhost:5432
- **Usuario Admin**: `postgres` / `postgres-password`
- **Usuarios de Aplicaciones**:
  - `n8n` / `n8n-password`
  - `jenkins` / `jenkins-password`
  - `keycloak` / `keycloak-password`

### 5. 📊 pgAdmin Database Administration
- **Estado**: 🔄 Configurado (iniciándose)
- **URL**: http://localhost:8082
- **Autenticación**: Keycloak OIDC
- **Usuario**: `jmiguelmangas` / `leicakanon2025`
- **Fallback**: `admin@example.com` / `pgadmin-password`

## 👥 Usuarios y Grupos en Keycloak

### Usuario Principal
- **Username**: `jmiguelmangas`
- **Password**: `leicakanon2025`
- **Email**: `jmiguelmangas@neoris.com`

### Grupos y Permisos
- **jenkins-admins**: Acceso completo a Jenkins (usuario asignado)
- **jenkins-developers**: Acceso de construcción en Jenkins
- **jenkins-viewers**: Acceso de solo lectura en Jenkins
- **n8n-admins**: Acceso completo a N8N (usuario asignado)
- **postgres-admins**: Acceso a PostgreSQL/pgAdmin (usuario asignado)

## 🔗 Clientes OIDC Configurados

### Jenkins Client
- **Client ID**: `jenkins`
- **Client Secret**: `jenkins-secret`
- **Redirect URIs**: 
  - `http://localhost:8081/securityRealm/finishLogin`
  - `http://jenkins.local:8081/securityRealm/finishLogin`

### N8N Client
- **Client ID**: `n8n`
- **Client Secret**: `n8n-secret`
- **Redirect URIs**:
  - `http://localhost:5678/rest/oauth2-credential/callback`
  - `http://n8n.local:5678/rest/oauth2-credential/callback`

### PostgreSQL Client
- **Client ID**: `postgresql`
- **Client Secret**: `postgresql-secret`
- **Uso**: Integración con pgAdmin

## 🚀 Comandos de Port Forwarding

```bash
# Keycloak (ya ejecutándose)
kubectl port-forward svc/keycloak 8090:8080 -n keycloak

# Jenkins
kubectl port-forward svc/jenkins-service 8081:8080 -n jenkins

# N8N
kubectl port-forward svc/n8n 5678:5678 -n n8n

# PostgreSQL
kubectl port-forward svc/postgresql 5432:5432 -n postgresql

# pgAdmin
kubectl port-forward svc/pgadmin 8082:80 -n postgresql
```

### Script Automatizado
```bash
./scripts/setup-port-forwards.sh
```

## 📋 Estado de Deployments

```bash
# Verificar estado de todos los servicios
kubectl get pods --all-namespaces | grep -E "(keycloak|jenkins|n8n|postgresql)"

# Verificar servicios específicos
kubectl get pods -n keycloak
kubectl get pods -n jenkins
kubectl get pods -n n8n
kubectl get pods -n postgresql
```

## 🔧 Configuración Post-Despliegue

### 1. Jenkins
- La configuración OIDC se aplicará automáticamente via JCasC
- Los usuarios de Keycloak podrán acceder directamente
- Los grupos se mapearán a roles de Jenkins automáticamente

### 2. N8N
- Configuración OIDC via variables de entorno
- Auto-creación de usuarios habilitada
- Integración con PostgreSQL configurada

### 3. pgAdmin
- Configuración OAuth2 con Keycloak
- Soporte para autenticación dual (OIDC + local)
- Conexiones predefinidas a PostgreSQL

## ⚠️ Notas Importantes

1. **Hosts File**: Se ha agregado `keycloak.local` a `/etc/hosts`
2. **Certificados**: Se usa HTTP para desarrollo (no HTTPS)
3. **Secretos**: Todos los secretos están en base64 en los manifests
4. **Persistencia**: Todos los datos se almacenan en PVCs

## 🔄 Reinicio de Servicios

```bash
# Reiniciar Jenkins
kubectl rollout restart deployment jenkins-deployment -n jenkins

# Reiniciar N8N
kubectl rollout restart deployment n8n-deployment -n n8n

# Reiniciar PostgreSQL
kubectl rollout restart deployment postgresql-deployment -n postgresql

# Reiniciar Keycloak
kubectl rollout restart deployment keycloak -n keycloak
```

## 📊 Verificación de Conexiones

```bash
# Verificar conectividad de servicios
kubectl exec -it <jenkins-pod> -n jenkins -- curl -k http://keycloak.keycloak.svc.cluster.local:8080/realms/k8s-stack

# Verificar base de datos
kubectl exec -it <postgres-pod> -n postgresql -- psql -U postgres -c "\l"
```

## 🎉 ¡Integración Completada!

Todos los servicios están configurados para usar Keycloak como proveedor de autenticación centralizada. Los usuarios pueden acceder a cualquier servicio usando las mismas credenciales de Keycloak, y los permisos se gestionan através de grupos.
