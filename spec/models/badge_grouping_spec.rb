# frozen_string_literal: true

require "rails_helper"

RSpec.describe BadgeGrouping, type: :model do
  it { is_expected.to validate_length_of(:name).is_at_most(100) }
  it { is_expected.to validate_length_of(:description).is_at_most(500) }
end
