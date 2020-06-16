# frozen_string_literal: true

require 'rails_helper'

describe UserCardSerializer do
  context "with a TL0 user seen as anonymous" do
    let(:user) { Fabricate.build(:user, trust_level: 0, user_profile: Fabricate.build(:user_profile)) }
    let(:serializer) { described_class.new(user, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "does not serialize emails" do
      expect(json[:secondary_emails]).to be_nil
      expect(json[:unconfirmed_emails]).to be_nil
    end
  end

  context "as current user" do
    it "serializes emails correctly" do
      user = Fabricate.build(:user,
                             id: 1,
                             user_profile: Fabricate.build(:user_profile),
                             user_option: UserOption.new(dynamic_favicon: true),
                             user_stat: UserStat.new
                            )
      json = described_class.new(user, scope: Guardian.new(user), root: false).as_json
      expect(json[:secondary_emails]).to eq([])
      expect(json[:unconfirmed_emails]).to eq([])
    end
  end

  context "as different user" do
    let(:user) { Fabricate(:user, trust_level: 0) }
    let(:user2) { Fabricate(:user, trust_level: 1) }
    it "does not serialize emails" do
      json = described_class.new(user, scope: Guardian.new(user2), root: false).as_json
      expect(json[:secondary_emails]).to be_nil
      expect(json[:unconfirmed_emails]).to be_nil
    end
  end
end
