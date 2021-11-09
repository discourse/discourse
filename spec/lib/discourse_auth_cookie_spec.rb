# frozen_string_literal: true

require "rails_helper"

describe DiscourseAuthCookie do
  fab!(:user) { Fabricate(:user) }

  describe ".parse" do
    it "does not attempt decryption or validations for v0 cookie" do
      token = SecureRandom.hex
      cookie = DiscourseAuthCookie.parse(token)
      expect(cookie.token).to eq(token)
    end

    it "decrypts/validates signature for cookies that are < 32 chars" do
      token = "asdad"
      expect {
        DiscourseAuthCookie.parse(token)
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)
    end

    it "decrypts/validates signature for v1 cookies" do
      cookie = DiscourseAuthCookie.new(
        token: SecureRandom.hex,
        user_id: user.id,
        trust_level: user.trust_level,
        issued_at: 5.minutes.ago,
      ).serialize

      cookie = swap_2_different_characters(cookie)

      expect {
        DiscourseAuthCookie.parse(cookie)
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)

      token = SecureRandom.hex
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        issued_at: 5.minutes.ago,
      ).serialize

      parsed = DiscourseAuthCookie.parse(cookie)
      expect(parsed.token).to eq(token)
    end

    it "correctly parses cookie fields" do
      token = SecureRandom.hex
      issued_at = 5.minutes.ago
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: user.id,
        trust_level: user.trust_level,
        issued_at: issued_at,
      ).serialize

      parsed = DiscourseAuthCookie.parse(cookie)
      expect(parsed.token).to eq(token)
      expect(parsed.user_id).to eq(user.id)
      expect(parsed.trust_level).to eq(user.trust_level)
      expect(Time.zone.at(parsed.issued_at)).to eq_time(Time.zone.at(issued_at.to_i))
    end

    it "works when there are missing fields in the cookie" do
      token = SecureRandom.hex
      issued_at = 5.minutes.ago
      cookie = DiscourseAuthCookie.new(
        token: token,
        user_id: nil,
        trust_level: nil,
        issued_at: issued_at
      ).serialize

      parsed = DiscourseAuthCookie.parse(cookie)
      expect(parsed.token).to eq(token)
      expect(parsed.user_id).to eq(nil)
      expect(parsed.trust_level).to eq(nil)
      expect(Time.zone.at(parsed.issued_at)).to eq_time(Time.zone.at(issued_at.to_i))
    end
  end

  describe ".new" do
    it "ensures auth token is the right lenght" do
      expect {
        DiscourseAuthCookie.new(token: SecureRandom.hex(8))
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)

      expect {
        DiscourseAuthCookie.new(token: SecureRandom.hex(50))
      }.to raise_error(DiscourseAuthCookie::InvalidCookie)
    end
  end
end
