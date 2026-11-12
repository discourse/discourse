# frozen_string_literal: true

Migrations::Tooling::Schema.table :user_associated_accounts do
  primary_key :user_id, :provider_name

  column :last_used, required: false

  ignore :credentials, :extra, :id
  ignore :avatar_upload_id, reason: "Downloaded from the provider's `info.image` on the next login"
end
