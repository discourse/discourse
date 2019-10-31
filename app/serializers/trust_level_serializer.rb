# frozen_string_literal: true

class TrustLevelSerializer < ApplicationSerializer
  root 'trust_level'

  attributes :id, :name

end
