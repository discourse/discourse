# frozen_string_literal: true

require_relative "support"

RSpec.describe JsonApiKit::Name::Member do
  subject(:name) { described_class.new(value: "after_size") }

  it_behaves_like "a name", :member
end
