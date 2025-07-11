# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:tl0_user) { Fabricate(:user, trust_level: 0, refresh_auto_groups: true) }
  fab!(:tl2_user) { Fabricate(:user, trust_level: 2, refresh_auto_groups: true) }
  fab!(:tl3_user) { Fabricate(:user, trust_level: 3, refresh_auto_groups: true) }
  fab!(:admin)

  let(:tl0_serializer) { described_class.new(tl0_user, scope: Guardian.new(tl0_user), root: false) }

  let(:tl2_serializer) { described_class.new(tl2_user, scope: Guardian.new(tl2_user), root: false) }

  let(:tl3_serializer) { described_class.new(tl3_user, scope: Guardian.new(tl3_user), root: false) }

  let(:admin_serializer) { described_class.new(admin, scope: Guardian.new(admin), root: false) }

  before { SiteSetting.discourse_adplugin_enabled = true }

  describe "#adsense" do
    it "is displayed for TL0 by default" do
      expect(tl0_serializer.show_adsense_ads).to eq(true)
    end

    it "is displayed for TL2 by default" do
      expect(tl2_serializer.show_adsense_ads).to eq(true)
    end

    it "is off for TL3 by default" do
      expect(tl3_serializer.show_adsense_ads).to eq(false)
    end

    it "is off for admin by default" do
      expect(admin_serializer.show_adsense_ads).to eq(false)
    end
  end

  describe "#amazon" do
    it "is displayed for TL0 by default" do
      expect(tl0_serializer.show_amazon_ads).to eq(true)
    end

    it "is displayed for TL2 by default" do
      expect(tl2_serializer.show_amazon_ads).to eq(true)
    end

    it "is off for TL3 by default" do
      expect(tl3_serializer.show_amazon_ads).to eq(false)
    end

    it "is off for admin by default" do
      expect(admin_serializer.show_amazon_ads).to eq(false)
    end
  end

  describe "#dfp" do
    it "is displayed for TL0 by default" do
      expect(tl0_serializer.show_dfp_ads).to eq(true)
    end

    it "is displayed for TL2 by default" do
      expect(tl2_serializer.show_dfp_ads).to eq(true)
    end

    it "is off for TL3 by default" do
      expect(tl3_serializer.show_dfp_ads).to eq(false)
    end

    it "is off for admin by default" do
      expect(admin_serializer.show_dfp_ads).to eq(false)
    end
  end

  describe "#carbon" do
    it "is displayed for TL0 by default" do
      expect(tl0_serializer.show_carbon_ads).to eq(true)
    end

    it "is displayed for TL2 by default" do
      expect(tl2_serializer.show_carbon_ads).to eq(true)
    end

    it "is off for TL3 by default" do
      expect(tl3_serializer.show_carbon_ads).to eq(false)
    end

    it "is off for admin by default" do
      expect(admin_serializer.show_carbon_ads).to eq(false)
    end
  end

  describe "#adbutler" do
    it "is displayed for TL0 by default" do
      expect(tl0_serializer.show_adbutler_ads).to eq(true)
    end

    it "is displayed for TL2 by default" do
      expect(tl2_serializer.show_adbutler_ads).to eq(true)
    end

    it "is off for TL3 by default" do
      expect(tl3_serializer.show_adbutler_ads).to eq(false)
    end

    it "is off for admin by default" do
      expect(admin_serializer.show_adbutler_ads).to eq(false)
    end
  end
end
