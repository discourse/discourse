# frozen_string_literal: true

class TestContract < Service::ContractBase
  attribute :channel_id, :integer

  attribute :record do
    attribute :id, :integer
    attribute :created_at, :datetime
    attribute :enabled, :boolean
  end

  attribute :user do
    attribute :username, :string

    validates :username, presence: true
  end
end
