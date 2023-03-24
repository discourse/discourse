# frozen_string_literal: true

class SingleSignOnRecordSerializer < ApplicationSerializer
  attributes :user_id,
             :external_id,
             :created_at,
             :updated_at,
             :external_username,
             :external_name,
             :external_avatar_url,
             :external_profile_background_url,
             :external_card_background_url
end
