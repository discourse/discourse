# frozen_string_literal: true

RSpec.describe GroupRequest do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :group }

  it do
    is_expected.to validate_length_of(:reason).is_at_most(described_class::REASON_CHARACTER_LIMIT)
  end
end
