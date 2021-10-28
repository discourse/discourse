# frozen_string_literal: true

require "rails_helper"

describe DiscourseAuthCookie do
  fab!(:user) { Fabricate(:user) }

  describe ".parse" do
    it "does not validate signature for v0 cookie" do
      token = SecureRandom.hex
      cookie = DiscourseAuthCookie.parse(token)
      expect(cookie.token).to eq(token)
    end

    it "validates signature for cookies that are < 32 chars" do
      token = "asdad"
      expect {
        DiscourseAuthCookie.parse(token)
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)
    end

    it "validates signature for v1 cookies" do
      cookie = DiscourseAuthCookie.new(
        token: SecureRandom.hex,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: 4.hours.ago,
        valid_for: 100.days
      ).to_text(SecureRandom.hex)

      expect {
        DiscourseAuthCookie.parse(cookie)
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)

      token = SecureRandom.hex
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: 4.hours.ago,
        valid_for: 100.days
      ).to_text(Rails.application.secret_key_base)

      parsed = DiscourseAuthCookie.parse(cookie)
      expect(parsed.token).to eq(token)
    end

    it "correctly parses cookie fields" do
      token = SecureRandom.hex
      timestamp = 4.hours.ago
      valid_for = 100.days
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      ).to_text(Rails.application.secret_key_base)

      parsed = DiscourseAuthCookie.parse(cookie)
      expect(parsed.token).to eq(token)
      expect(parsed.user_id).to eq(user.id)
      expect(parsed.trust_level).to eq(user.trust_level)
      expect(parsed.timestamp).to eq(timestamp.to_i)
      expect(parsed.valid_for).to eq(valid_for.to_i)
    end

    it "works when there are missing fields in the cookie" do
      token = SecureRandom.hex
      timestamp = 4.hours.ago
      valid_for = 100.days
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: nil,
        trust_level: nil,
        timestamp: timestamp,
        valid_for: valid_for
      ).to_text(Rails.application.secret_key_base)

      parsed = DiscourseAuthCookie.parse(cookie)
      expect(parsed.token).to eq(token)
      expect(parsed.user_id).to eq(nil)
      expect(parsed.trust_level).to eq(nil)
      expect(parsed.timestamp).to eq(timestamp.to_i)
      expect(parsed.valid_for).to eq(valid_for.to_i)
    end

    it "does not require cookie fields to be in any particular order" do
      token = SecureRandom.hex
      timestamp = 4.hours.ago
      valid_for = 100.days
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      ).to_text(Rails.application.secret_key_base)

      data, = cookie.split("|", 2)
      data = data.split(",").shuffle.join(",")
      cookie = [
        data,
        DiscourseAuthCookie.compute_signature(data, Rails.application.secret_key_base)
      ].join("|")

      parsed = DiscourseAuthCookie.parse(cookie)
      expect(parsed.token).to eq(token)
      expect(parsed.user_id).to eq(user.id)
      expect(parsed.trust_level).to eq(user.trust_level)
      expect(parsed.timestamp).to eq(timestamp.to_i)
      expect(parsed.valid_for).to eq(valid_for.to_i)
    end
  end

  describe "#to_text" do
    it "converts the instance to a string with a signature" do
      token = SecureRandom.hex
      timestamp = 4.hours.ago
      valid_for = 100.days
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      ).to_text(Rails.application.secret_key_base)

      data, sig = cookie.split("|", 2)
      parts = data.split(",")
      expect(sig).to match(/\A\h{64}\Z/)
      expect(parts.size).to eq(5)
      expect(parts).to include("token:#{token}")
      expect(parts).to include("id:#{user.id}")
      expect(parts).to include("tl:#{user.trust_level}")
      expect(parts).to include("time:#{timestamp.to_i}")
      expect(parts).to include("valid:#{valid_for.to_i}")
    end

    it "works when some fields are nil" do
      token = SecureRandom.hex
      timestamp = 4.hours.ago
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: nil,
        trust_level: nil,
        timestamp: timestamp,
        valid_for: nil
      ).to_text(Rails.application.secret_key_base)

      data, sig = cookie.split("|", 2)
      parts = data.split(",")
      expect(sig).to eq(OpenSSL::HMAC.hexdigest("sha256", Rails.application.secret_key_base, data))
      expect(parts.size).to eq(5)
      expect(parts).to include("token:#{token}")
      expect(parts).to include("id:")
      expect(parts).to include("tl:")
      expect(parts).to include("time:#{timestamp.to_i}")
      expect(parts).to include("valid:")
    end
  end

  describe "#validate!" do
    it "ensures token has the right length" do
      token = SecureRandom.hex(8)
      timestamp = 4.hours.ago
      valid_for = 100.days
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      )

      expect {
        cookie.validate!
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)

      token = SecureRandom.hex(50)
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      )

      expect {
        cookie.validate!
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)

      token = SecureRandom.hex(16)
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      )
      # no error is raised
      cookie.validate!
    end

    it "ensures cookie is not older than what the timestamp+valid_for fields say" do
      token = SecureRandom.hex
      timestamp = 4.hours.ago
      valid_for = 2.hours
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      )
      expect {
        cookie.validate!
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)

      valid_for = 20.hours
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      )
      # no error is raised
      cookie.validate!
    end

    it "does not validate age if validate_age is false" do
      token = SecureRandom.hex
      timestamp = 4.hours.ago
      valid_for = 2.hours
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        timestamp: timestamp,
        valid_for: valid_for
      )
      # no error is raised
      cookie.validate!(validate_age: false)
    end
  end
end
