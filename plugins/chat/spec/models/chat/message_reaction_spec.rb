# frozen_string_literal: true

RSpec.describe Chat::MessageReaction do
  it { is_expected.to validate_length_of(:emoji).is_at_most(100) }
end
