# frozen_string_literal: true

class SingleSignOnRecordSerializer < ApplicationSerializer
  attributes :user_id, :external_id,
             :last_payload, :created_at,
             :updated_at, :external_username,
             :external_email, :external_name,
             :external_avatar_url,
             :external_profile_background_url,
             :external_card_background_url

  def include_external_email?
    scope.is_admin?
  end
end
