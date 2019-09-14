# frozen_string_literal: true

require 'rails_helper'

describe SecureSession do
  it "operates correctly" do
    s = SecureSession.new("abc")

    s["hello"] = "world"
    s["foo"] = "bar"
    expect(s["hello"]).to eq("world")
    expect(s["foo"]).to eq("bar")

    s["hello"] = nil
    expect(s["hello"]).to eq(nil)
  end
end
