################################################################################
# Derived locals from service_db_config
################################################################################

locals {
  # Services that own a schema → create schema + role + full CRUD grants
  schema_owning_services = {
    for k, v in var.service_db_config : k => v if v.owns_schema
  }

  # Services that need DB connectivity → secret + proxy auth entry
  db_services = {
    for k, v in var.service_db_config : k => v if v.needs_db
  }

  # Services that use only the public schema (no owned schema, but need DB)
  public_schema_services = {
    for k, v in var.service_db_config : k => v if v.needs_db && !v.owns_schema
  }

  # Proxy auth mirrors db_services (every DB-using service gets a proxy entry)
  proxy_auth_services = local.db_services
}
