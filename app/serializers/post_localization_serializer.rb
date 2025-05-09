# frozen_string_literal: true

class PostLocalizationSerializer < ApplicationSerializer
  attributes :id, :post_id, :locale, :raw
end
