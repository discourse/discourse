# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSerializer do
  let(:user) { Fabricate(:user, date_of_birth: "2017-04-05") }
  let(:post) { Fabricate(:post, user: user) }

  context "when user is logged in" do
    let(:serializer) { described_class.new(post, scope: Guardian.new(user), root: false) }

    it "should include both the user's birthdate and cakedate" do
      expect(serializer.as_json[:user_birthdate]).to eq(user.date_of_birth)
      expect(serializer.as_json[:user_cakedate]).to eq(user.created_at.strftime("%Y-%m-%d"))
    end

    it "should not include the user's cakedate when cakeday_enabled is false" do
      SiteSetting.cakeday_enabled = false
      expect(serializer.as_json.has_key?(:user_cakedate)).to eq(false)
    end

    it "should not include the user's birthdate when cakeday_birthday_enabled is false" do
      SiteSetting.cakeday_birthday_enabled = false
      expect(serializer.as_json.has_key?(:user_birthdate)).to eq(false)
    end

    context "when user has hidden their profile" do
      before { user.user_option.update!(hide_profile: true) }

      it "should not include the user's cakedate" do
        expect(serializer.as_json.has_key?(:user_cakedate)).to eq(false)
      end

      it "should not include the user's birthdate" do
        expect(serializer.as_json.has_key?(:user_birthdate)).to eq(false)
      end
    end
  end

  context "when user is not logged in" do
    let(:serializer) { described_class.new(post, scope: Guardian.new, root: false) }

    it "should not include the user's birthdate nor the cakedate" do
      expect(serializer.as_json.has_key?(:user_birthdate)).to eq(false)
      expect(serializer.as_json.has_key?(:user_cakedate)).to eq(false)
    end
  end
end
