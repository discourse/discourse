# frozen_string_literal: true

RSpec.describe BadgeType do
  it { is_expected.to have_many :badges }
  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_uniqueness_of :name }
end
