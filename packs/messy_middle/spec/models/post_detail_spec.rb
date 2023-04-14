# frozen_string_literal: true

RSpec.describe PostDetail do
  it { is_expected.to belong_to :post }

  it { is_expected.to validate_presence_of :key }
  it { is_expected.to validate_presence_of :value }
  it { is_expected.to validate_uniqueness_of(:key).scoped_to(:post_id) }
end
