# frozen_string_literal: true

describe BasicReviewableSerializer do
  fab!(:reviewable)
  subject { described_class.new(reviewable, scope: PlaceholderGuardian.new, root: false).as_json }

  include_examples "basic reviewable attributes"
end
