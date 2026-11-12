# frozen_string_literal: true

RSpec.describe PostSerializer do
  let(:user) { Fabricate(:user, date_of_birth: "2017-04-05") }
  let(:post) { Fabricate(:post, user: user) }

  context "when user is logged in" do
    let(:serializer) { described_class.new(post, scope: Guardian.new(user), root: false) }

    it "includes both the user's birthdate and cakedate" do
      SiteSetting.cakeday_enabled = true
      SiteSetting.cakeday_birthday_enabled = true
      expect(serializer.as_json[:user_birthdate]).to eq(user.date_of_birth)
      expect(serializer.as_json[:user_cakedate]).to eq(user.created_at.strftime("%Y-%m-%d"))
    end

    it "does not include the user's cakedate when cakeday_enabled is false" do
      SiteSetting.cakeday_enabled = false
      SiteSetting.cakeday_birthday_enabled = true
      expect(serializer.as_json.has_key?(:user_cakedate)).to eq(false)
    end

    it "does not include the user's birthdate when cakeday_birthday_enabled is false" do
      SiteSetting.cakeday_enabled = true
      SiteSetting.cakeday_birthday_enabled = false
      expect(serializer.as_json.has_key?(:user_birthdate)).to eq(false)
    end

    context "when user has hidden their profile" do
      before do
        SiteSetting.cakeday_enabled = true
        SiteSetting.cakeday_birthday_enabled = true
        user.user_option.update!(hide_profile: true)
      end

      it "still includes cakedate and birthdate for the user's own posts" do
        expect(serializer.as_json[:user_cakedate]).to eq(user.created_at.strftime("%Y-%m-%d"))
        expect(serializer.as_json[:user_birthdate]).to eq(user.date_of_birth)
      end

      it "does not include cakedate or birthdate for other users viewing the post" do
        other_user = Fabricate(:user)
        other_serializer = described_class.new(post, scope: Guardian.new(other_user), root: false)
        expect(other_serializer.as_json.has_key?(:user_cakedate)).to eq(false)
        expect(other_serializer.as_json.has_key?(:user_birthdate)).to eq(false)
      end
    end
  end

  context "when user is not logged in" do
    before do
      SiteSetting.cakeday_enabled = true
      SiteSetting.cakeday_birthday_enabled = true
    end

    let(:serializer) { described_class.new(post, scope: Guardian.new, root: false) }

    it "does not include the user's birthdate nor the cakedate" do
      expect(serializer.as_json.has_key?(:user_birthdate)).to eq(false)
      expect(serializer.as_json.has_key?(:user_cakedate)).to eq(false)
    end
  end
end
