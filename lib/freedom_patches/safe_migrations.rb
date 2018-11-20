require_dependency 'migration/safe_migrate'

Migration::SafeMigrate.patch_active_record!
