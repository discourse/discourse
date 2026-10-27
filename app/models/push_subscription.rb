# frozen_string_literal: true

class PushSubscription < ActiveRecord::Base
  MAX_ENDPOINT_BYTES = 2048

  belongs_to :user

  def self.normalize_endpoint(endpoint)
    return endpoint if endpoint.nil?

    normalized = Addressable::URI.parse(endpoint).normalize.omit(:fragment).to_s
    raise Discourse::InvalidParameters.new(:endpoint) if normalized.bytesize > MAX_ENDPOINT_BYTES
    normalized
  rescue Addressable::URI::InvalidURIError
    raise Discourse::InvalidParameters.new(:endpoint)
  end

  def parsed_data
    JSON.parse(data)
  end
end

# == Schema Information
#
# Table name: push_subscriptions
#
#  id             :bigint           not null, primary key
#  data           :string           not null
#  error_count    :integer          default(0), not null
#  first_error_at :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :integer          not null
#
# Indexes
#
#  index_push_subscriptions_on_endpoint  ((((data)::jsonb ->> 'endpoint'::text))) UNIQUE WHERE (octet_length(((data)::jsonb ->> 'endpoint'::text)) <= 2048)
#
