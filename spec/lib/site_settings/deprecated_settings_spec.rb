# frozen_string_literal: true

RSpec.xdescribe SiteSettings::DeprecatedSettings do
  def deprecate_override!(settings, tl_group_overrides = [])
    @original_settings = SiteSettings::DeprecatedSettings::SETTINGS.dup
    SiteSettings::DeprecatedSettings::SETTINGS.clear
    SiteSettings::DeprecatedSettings::SETTINGS.push(settings)

    if tl_group_overrides.any?
      @original_override_tl_group = SiteSettings::DeprecatedSettings::OVERRIDE_TL_GROUP_SETTINGS.dup
      SiteSettings::DeprecatedSettings::OVERRIDE_TL_GROUP_SETTINGS.clear
      SiteSettings::DeprecatedSettings::OVERRIDE_TL_GROUP_SETTINGS.push(*tl_group_overrides)
    end

    SiteSetting.setup_deprecated_methods
  end

  after do
    if defined?(@original_settings)
      SiteSettings::DeprecatedSettings::SETTINGS.clear
      SiteSettings::DeprecatedSettings::SETTINGS.concat(@original_settings)
    end

    if defined?(@original_override_tl_group)
      SiteSettings::DeprecatedSettings::OVERRIDE_TL_GROUP_SETTINGS.clear
      SiteSettings::DeprecatedSettings::OVERRIDE_TL_GROUP_SETTINGS.concat(
        @original_override_tl_group,
      )
    end

    SiteSetting.setup_deprecated_methods
  end

  describe "when not overriding deprecated settings" do
    let(:override) { false }

    # NOTE: This fixture has some completely made up settings (e.g. min_trust_level_to_allow_invite_tl_and_staff)
    let(:deprecated_test) { "#{Rails.root}/spec/fixtures/site_settings/deprecated_test.yml" }

    before do
      SiteSetting.force_https = true
      SiteSetting.load_settings(deprecated_test)
    end

    it "should not act as a proxy to the new methods" do
      deprecate_override!(["use_https", "force_https", override, "0.0.1"])

      SiteSetting.use_https = false

      expect(SiteSetting.force_https).to eq(true)
      expect(SiteSetting.force_https?).to eq(true)
    end

    it "should log warnings when deprecated settings are called" do
      deprecate_override!(["use_https", "force_https", override, "0.0.1"])

      logger =
        track_log_messages do
          expect(SiteSetting.use_https).to eq(true)
          expect(SiteSetting.use_https?).to eq(true)
        end
      expect(logger.warnings.count).to eq(3)

      logger = track_log_messages { SiteSetting.use_https(warn: false) }
      expect(logger.warnings.count).to eq(0)
    end
  end

  describe "when overriding deprecated settings" do
    let(:override) { true }
    let(:deprecated_test) { "#{Rails.root}/spec/fixtures/site_settings/deprecated_test.yml" }

    before do
      SiteSetting.force_https = true
      SiteSetting.load_settings(deprecated_test)
    end

    it "should act as a proxy to the new methods" do
      deprecate_override!(["use_https", "force_https", override, "0.0.1"])

      SiteSetting.use_https = false

      expect(SiteSetting.force_https).to eq(false)
      expect(SiteSetting.force_https?).to eq(false)
    end

    xit "should log warnings when deprecated settings are called" do
      deprecate_override!(["use_https", "force_https", override, "0.0.1"])

      logger =
        track_log_messages do
          expect(SiteSetting.use_https).to eq(true)
          expect(SiteSetting.use_https?).to eq(true)
        end
      expect(logger.warnings.count).to eq(2)

      logger = track_log_messages { SiteSetting.use_https(warn: false) }
      expect(logger.warnings.count).to eq(0)
    end
  end

  describe "when overriding a trust level setting with a group setting" do
    let(:override) { false }
    let(:deprecated_test) { "#{Rails.root}/spec/fixtures/site_settings/deprecated_test.yml" }

    before { SiteSetting.load_settings(deprecated_test) }

    context "when getting an old TrustLevelSetting" do
      before do
        deprecate_override!(
          ["min_trust_level_to_allow_invite", "invite_allowed_groups", override, "0.0.1"],
        )
      end

      it "uses the minimum trust level from the trust level auto groups in the new group setting" do
        SiteSetting.invite_allowed_groups =
          "#{Group::AUTO_GROUPS[:trust_level_3]}|#{Group::AUTO_GROUPS[:trust_level_4]}"
        expect(SiteSetting.min_trust_level_to_allow_invite).to eq(TrustLevel[3])
      end

      it "returns TL4 if there are no trust level auto groups in the new group setting" do
        SiteSetting.invite_allowed_groups = Fabricate(:group).id.to_s
        expect(SiteSetting.min_trust_level_to_allow_invite).to eq(TrustLevel[4])
      end

      it "returns TL4 if there are only staff and admin auto groups in the new group setting" do
        SiteSetting.invite_allowed_groups =
          "#{Group::AUTO_GROUPS[:admins]}|#{Group::AUTO_GROUPS[:staff]}"
        expect(SiteSetting.min_trust_level_to_allow_invite).to eq(TrustLevel[4])
      end

      it "returns TL4 if there are no automated invite_allowed_groups" do
        SiteSetting.invite_allowed_groups = Fabricate(:group).id.to_s
        expect(SiteSetting.min_trust_level_to_allow_invite).to eq(TrustLevel[4])
      end
    end

    context "when getting an old TrustLevelAndStaffSetting" do
      before do
        deprecate_override!(
          [
            "min_trust_level_to_allow_invite_tl_and_staff",
            "invite_allowed_groups",
            override,
            "0.0.1",
          ],
          ["min_trust_level_to_allow_invite_tl_and_staff"],
        )
      end

      it "returns moderator if there is only the moderators auto group in the new group setting" do
        SiteSetting.invite_allowed_groups = "#{Group::AUTO_GROUPS[:moderators]}"
        expect(SiteSetting.min_trust_level_to_allow_invite_tl_and_staff).to eq("moderator")
      end

      it "returns staff if there are staff and admin auto groups in the new group setting" do
        SiteSetting.invite_allowed_groups =
          "#{Group::AUTO_GROUPS[:admins]}|#{Group::AUTO_GROUPS[:staff]}"
        expect(SiteSetting.min_trust_level_to_allow_invite_tl_and_staff).to eq("staff")
      end

      it "returns admin if there is only the admin auto group in the new group setting" do
        SiteSetting.invite_allowed_groups = "#{Group::AUTO_GROUPS[:admins]}"
        expect(SiteSetting.min_trust_level_to_allow_invite_tl_and_staff).to eq("admin")
      end

      it "returns the min trust level if the admin auto group as well as lower TL auto groups in the new group setting" do
        SiteSetting.invite_allowed_groups =
          "#{Group::AUTO_GROUPS[:admins]}|#{Group::AUTO_GROUPS[:trust_level_3]}"
        expect(SiteSetting.min_trust_level_to_allow_invite_tl_and_staff).to eq(TrustLevel[3])
      end

      it "returns admin if there are no automated invite_allowed_groups" do
        SiteSetting.invite_allowed_groups = Fabricate(:group).id.to_s
        expect(SiteSetting.min_trust_level_to_allow_invite_tl_and_staff).to eq("admin")
      end
    end

    context "when setting an old TrustLevelSetting" do
      before do
        deprecate_override!(
          ["min_trust_level_to_allow_invite", "invite_allowed_groups", override, "0.0.1"],
          ["min_trust_level_to_allow_invite"],
        )
      end

      it "converts the provided trust level to the appropriate auto group" do
        SiteSetting.min_trust_level_to_allow_invite = TrustLevel[4]
        expect(SiteSetting.min_trust_level_to_allow_invite).to eq(TrustLevel[4])
        expect(SiteSetting.invite_allowed_groups).to eq(Group::AUTO_GROUPS[:trust_level_4].to_s)
      end

      it "raises error with an invalid trust level" do
        expect { SiteSetting.min_trust_level_to_allow_invite = 66 }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
    end

    context "when setting an old TrustLevelAndStaffSetting" do
      before do
        deprecate_override!(
          [
            "min_trust_level_to_allow_invite_tl_and_staff",
            "invite_allowed_groups",
            override,
            "0.0.1",
          ],
          ["min_trust_level_to_allow_invite_tl_and_staff"],
        )
      end

      it "converts the provided trust level to the appropriate auto group" do
        SiteSetting.min_trust_level_to_allow_invite_tl_and_staff = "admin"
        expect(SiteSetting.min_trust_level_to_allow_invite_tl_and_staff).to eq("admin")
        expect(SiteSetting.invite_allowed_groups).to eq(Group::AUTO_GROUPS[:admins].to_s)

        SiteSetting.min_trust_level_to_allow_invite_tl_and_staff = "staff"
        expect(SiteSetting.min_trust_level_to_allow_invite_tl_and_staff).to eq("staff")
        expect(SiteSetting.invite_allowed_groups).to eq(Group::AUTO_GROUPS[:staff].to_s)

        SiteSetting.min_trust_level_to_allow_invite_tl_and_staff = TrustLevel[3]
        expect(SiteSetting.min_trust_level_to_allow_invite_tl_and_staff).to eq(TrustLevel[3])
        expect(SiteSetting.invite_allowed_groups).to eq(
          "#{Group::AUTO_GROUPS[:admins]}|#{Group::AUTO_GROUPS[:staff]}|#{Group::AUTO_GROUPS[:trust_level_3]}",
        )
      end

      it "raises error with an invalid trust level" do
        expect { SiteSetting.min_trust_level_to_allow_invite_tl_and_staff = 66 }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
    end
  end
end
