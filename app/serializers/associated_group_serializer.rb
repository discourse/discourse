# frozen_string_literal: true

class AssociatedGroupSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :provider_name,
             :provider_domain
end
