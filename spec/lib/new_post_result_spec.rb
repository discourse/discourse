# frozen_string_literal: true

require 'rails_helper'
require 'new_post_result'

describe NewPostResult do

  it "fails by default" do
    result = NewPostResult.new(:eviltrout)
    expect(result.failed?).to eq(true)
    expect(result.success?).to eq(false)
  end

end
