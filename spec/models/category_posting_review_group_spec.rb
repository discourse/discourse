# frozen_string_literal: true

RSpec.describe CategoryPostingReviewGroup do
  fab!(:category)

  subject { described_class.new(category: category, group: Group[:everyone], post_type: :topic) }

  it { is_expected.to validate_presence_of(:category) }
  it { is_expected.to validate_presence_of(:group) }
end
