# frozen_string_literal: true

RSpec.describe ServerSession do
  subject(:session) { described_class.new("abc") }

  it "operates correctly" do
    session["hello"] = "world"
    session["foo"] = "bar"
    expect(session["hello"]).to eq("world")
    expect(session["foo"]).to eq("bar")

    session["hello"] = nil
    expect(session["hello"]).to be_nil
  end

  it "can override expiry" do
    key = SecureRandom.hex

    session.set(key, "test2", expires: 5.minutes)
    expect(session.ttl(key)).to be_within(1.second).of(5.minutes)

    key = SecureRandom.hex
    session.set(key, "test2")
    expect(session.ttl(key)).to be_within(1.second).of(described_class.expiry)
  end
end
