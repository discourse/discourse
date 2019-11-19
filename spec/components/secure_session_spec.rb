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

  it "can override expiry" do
    s = SecureSession.new("abc")
    key = SecureRandom.hex

    s.set(key, "test2", expires: 5.minutes)
    expect(s.ttl(key)).to be_within(1.second).of (5.minutes)

    key = SecureRandom.hex
    s.set(key, "test2")
    expect(s.ttl(key)).to be_within(1.second).of (SecureSession.expiry)
  end
end
