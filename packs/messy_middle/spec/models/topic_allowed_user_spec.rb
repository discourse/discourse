# frozen_string_literal: true

RSpec.describe TopicAllowedUser do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :topic }
end
