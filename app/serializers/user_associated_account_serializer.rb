# frozen_string_literal: true

class UserAssociatedAccountSerializer < ApplicationSerializer
  attributes :id,
             :provider_name,
             :provider_uid
end
