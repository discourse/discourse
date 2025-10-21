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

  describe "#[]" do
    let(:hash) { { symbol: :value, integer: 1, time: Time.current }.with_indifferent_access }

    before { session[:my_hash] = hash }

    it "returns complex objects properly" do
      expect(session[:my_hash]).to eq(hash)
    end

    context "when key is a string" do
      it "returns the proper value" do
        expect(session["my_hash"]).to eq(hash)
      end
    end

    context "when key is not found" do
      it "returns nil" do
        expect(session[:non_existent_key]).to be_nil
      end
    end

    context "when accessing an old value that wasn't serialized" do
      before { Discourse.redis.setex("abcoldvalue", 1.minute.to_i, "non-serialized value") }

      it "returns the old value" do
        expect(session[:oldvalue]).to eq("non-serialized value")
      end
    end
  end

  describe "#delete" do
    before { session[:key] = "value" }

    it "deletes the key from Redis" do
      expect { session.delete(:key) }.to change { Discourse.redis.exists?("abckey") }.to(false)
    end
  end
end
