# frozen_string_literal: true

require "new_post_result"

RSpec.describe NewPostResult do
  it "fails by default" do
    result = NewPostResult.new(:eviltrout)
    expect(result.failed?).to eq(true)
    expect(result.success?).to eq(false)
  end
end
