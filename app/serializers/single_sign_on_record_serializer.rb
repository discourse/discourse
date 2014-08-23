class SingleSignOnRecordSerializer < ApplicationSerializer
  attributes :user_id, :external_id,
             :last_payload, :created_at,
             :updated_at, :external_username,
             :external_email, :external_name,
             :external_avatar_url
end
