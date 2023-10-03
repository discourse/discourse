# frozen_string_literal: true

RSpec.describe GroupRequest do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :group }
  it { is_expected.to validate_length_of(:reason).is_at_most(5000) }
end
