# frozen_string_literal: true

describe BasicReviewableSerializer do
  fab!(:reviewable) { Fabricate(:reviewable) }
  subject { described_class.new(reviewable, root: false).as_json }

  include_examples "common basic reviewable serializer"
end
