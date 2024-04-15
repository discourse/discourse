# frozen_string_literal: true

RSpec.describe Chat::MessageRevision do
  it { is_expected.to validate_length_of(:old_message).is_at_most(50_000) }
  it { is_expected.to validate_length_of(:new_message).is_at_most(50_000) }
end
