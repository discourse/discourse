# frozen_string_literal: true

# One row per distinct upload created in the migration environment, keyed by its
# `Upload#id`. This is the dedup unit: many `upload_results` can point at the same
# upload via sha1 dedup.
Migrations::Tooling::Schema.table :uploads do
  ignore :user_id,
         reason:
           "Always the system user in the migration environment; the import step assigns the real owner"

  ignore :access_control_post_id,
         reason:
           "Migration-environment post id, not portable; secure-upload ACLs are re-established after import"

  ignore :retain_hours, reason: "Not meaningful for imported files"
end
