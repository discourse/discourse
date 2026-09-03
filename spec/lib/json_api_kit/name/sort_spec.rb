# frozen_string_literal: true

require_relative "support"

RSpec.describe JsonApiKit::Name::Sort do
  subject(:name) { described_class.new(value: "posted_at", type: "topics") }

  it_behaves_like "a name", :sort
end
