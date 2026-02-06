# frozen_string_literal: true

RSpec.describe PostItemExcerpt do
  fab!(:post) { Fabricate(:post, raw: "abc " * 100) }

  class DummyExcerptSerializer < ApplicationSerializer
    include PostItemExcerpt
  end

  it "includes excerpt and truncated attributes" do
    json = DummyExcerptSerializer.new(post, scope: Guardian.new, root: false).as_json

    expect(json[:excerpt]).to be_present
    expect(json[:truncated]).to eq(true)
  end
end
