# frozen_string_literal: true

require 'rails_helper'

describe NewPostResultSerializer do

  it "includes the message and route_to if present" do
    result = NewPostResult.new(:custom, true)
    result.message = 'hello :)'
    result.route_to = "/cool-route"

    serializer = described_class.new(result)
    expect(serializer.success).to eq(true)
    expect(serializer.message).to eq('hello :)')
    expect(serializer.route_to).to eq('/cool-route')
  end
end
