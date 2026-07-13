# frozen_string_literal: true

RSpec.describe UpcomingChanges do
  let(:setting_name) { :enable_upload_debug_mode }

  before do
    mock_upcoming_change_metadata(
      {
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: :experimental,
          impact_type: "other",
          impact_role: "developers",
        },
        conceptual_setting: {
          status: :conceptual,
        },
        alpha_setting: {
          status: :alpha,
        },
        beta_setting: {
          status: :beta,
        },
        stable_setting: {
          status: :stable,
        },
        permanent_setting: {
          status: :permanent,
        },
      },
    )

    # There is a fixture image at spec/fixtures/images/upcoming_changes/enable_upload_debug_mode.png,
    # but normally upcoming change images are at Rails.public_path + /images/upcoming_changes/
    Rails.stubs(:public_path).returns(Rails.root.join("spec/fixtures").to_s)
  end

  describe ".image_exists?" do
    it "returns true when the image file exists" do
      expect(described_class.image_exists?(setting_name)).to eq(true)
    end

    it "returns false when the image file does not exist" do
      expect(described_class.image_exists?("nonexistent_setting")).to eq(false)
    end
  end

  describe ".image_path" do
    it "returns the correct path for the image" do
      expect(described_class.image_path(setting_name)).to eq(
        "images/upcoming_changes/#{setting_name}.png",
      )
    end

    it "returns the correct path for plugin images" do
      plugin_setting = :enable_experimental_sample_plugin_feature

      expect(described_class.image_path(plugin_setting)).to eq(
        "plugins/discourse-sample-plugin/images/upcoming_changes/#{plugin_setting}.png",
      )
    end
  end

  describe ".image_data" do
    it "returns image URL, width, and height" do
      result = described_class.image_data(setting_name)

      expect(result[:url]).to eq(
        "#{Discourse.base_url}/images/upcoming_changes/#{setting_name}.png",
      )
      expect(result[:width]).to eq(244)
      expect(result[:height]).to eq(66)
    end

    context "when include_file_path is true" do
      it "returns the image URL, width, height, and file path" do
        result = described_class.image_data(setting_name, include_file_path: true)

        expect(result[:file_path]).to eq(
          Rails
            .root
            .join("spec", "fixtures", "images", "upcoming_changes", "#{setting_name}.png")
            .to_s,
        )
      end
    end
  end

  describe ".change_metadata" do
    it "returns the metadata hash for a setting with metadata" do
      metadata = described_class.change_metadata(setting_name)

      expect(metadata).to eq(
        {
          impact: "other,developers",
          status: :experimental,
          impact_type: "other",
          impact_role: "developers",
        },
      )
    end

    it "returns an empty hash for a setting without metadata" do
      metadata = described_class.change_metadata("nonexistent_setting")

      expect(metadata).to eq({})
    end

    it "accepts string setting names" do
      metadata = described_class.change_metadata(setting_name)

      expect(metadata[:status]).to eq(:experimental)
    end

    it "accepts symbol setting names" do
      metadata = described_class.change_metadata(setting_name.to_sym)

      expect(metadata[:status]).to eq(:experimental)
    end
  end

  describe ".not_yet_stable?" do
    it "returns true for conceptual status" do
      expect(described_class.not_yet_stable?("conceptual_setting")).to eq(true)
    end

    it "returns true for experimental status" do
      expect(described_class.not_yet_stable?(setting_name)).to eq(true)
    end

    it "returns true for alpha status" do
      expect(described_class.not_yet_stable?("alpha_setting")).to eq(true)
    end

    it "returns true for beta status" do
      expect(described_class.not_yet_stable?("beta_setting")).to eq(true)
    end

    it "returns false for stable status" do
      expect(described_class.not_yet_stable?("stable_setting")).to eq(false)
    end

    it "returns false for permanent status" do
      expect(described_class.not_yet_stable?("permanent_setting")).to eq(false)
    end
  end

  describe ".stable_or_permanent?" do
    it "returns false for conceptual status" do
      expect(described_class.stable_or_permanent?("conceptual_setting")).to eq(false)
    end

    it "returns false for experimental status" do
      expect(described_class.stable_or_permanent?(setting_name)).to eq(false)
    end

    it "returns false for alpha status" do
      expect(described_class.stable_or_permanent?("alpha_setting")).to eq(false)
    end

    it "returns false for beta status" do
      expect(described_class.stable_or_permanent?("beta_setting")).to eq(false)
    end

    it "returns true for stable status" do
      expect(described_class.stable_or_permanent?("stable_setting")).to eq(true)
    end

    it "returns true for permanent status" do
      expect(described_class.stable_or_permanent?("permanent_setting")).to eq(true)
    end
  end

  describe ".change_status_value" do
    it "returns -100 for conceptual status" do
      expect(described_class.change_status_value("conceptual_setting")).to eq(-100)
    end

    it "returns 0 for experimental status" do
      expect(described_class.change_status_value(setting_name)).to eq(0)
    end

    it "returns 100 for alpha status" do
      expect(described_class.change_status_value("alpha_setting")).to eq(100)
    end

    it "returns 200 for beta status" do
      expect(described_class.change_status_value("beta_setting")).to eq(200)
    end

    it "returns 300 for stable status" do
      expect(described_class.change_status_value("stable_setting")).to eq(300)
    end

    it "returns 500 for permanent status" do
      expect(described_class.change_status_value("permanent_setting")).to eq(500)
    end
  end

  describe ".change_status" do
    it "returns :conceptual for conceptual status" do
      expect(described_class.change_status("conceptual_setting")).to eq(:conceptual)
    end

    it "returns :experimental for experimental status" do
      expect(described_class.change_status(setting_name)).to eq(:experimental)
    end

    it "returns :alpha for alpha status" do
      expect(described_class.change_status("alpha_setting")).to eq(:alpha)
    end

    it "returns :beta for beta status" do
      expect(described_class.change_status("beta_setting")).to eq(:beta)
    end

    it "returns :stable for stable status" do
      expect(described_class.change_status("stable_setting")).to eq(:stable)
    end

    it "returns :permanent for permanent status" do
      expect(described_class.change_status("permanent_setting")).to eq(:permanent)
    end
  end

  describe ".meets_or_exceeds_status?" do
    it "returns true when the change meets the required status" do
      expect(described_class.meets_or_exceeds_status?("stable_setting", :beta)).to eq(true)
      expect(described_class.meets_or_exceeds_status?("permanent_setting", :stable)).to eq(true)
    end

    it "returns false when the change does not meet the required status" do
      expect(described_class.meets_or_exceeds_status?("alpha_setting", :beta)).to eq(false)
      expect(described_class.meets_or_exceeds_status?("beta_setting", :stable)).to eq(false)
    end
  end

  describe ".previous_status_value" do
    it "returns -100 for conceptual (lowest status)" do
      expect(described_class.previous_status_value(:conceptual)).to eq(-100)
    end

    it "returns -100 for experimental" do
      expect(described_class.previous_status_value(:experimental)).to eq(-100)
    end

    it "returns 0 for alpha" do
      expect(described_class.previous_status_value(:alpha)).to eq(0)
    end

    it "returns 100 for beta" do
      expect(described_class.previous_status_value(:beta)).to eq(100)
    end

    it "returns 200 for stable" do
      expect(described_class.previous_status_value(:stable)).to eq(200)
    end

    it "returns 300 for permanent" do
      expect(described_class.previous_status_value(:permanent)).to eq(300)
    end

    it "accepts string status names" do
      expect(described_class.previous_status_value("stable")).to eq(200)
    end
  end

  describe ".previous_status" do
    it "returns :conceptual for conceptual (lowest status)" do
      expect(described_class.previous_status(:conceptual)).to eq(:conceptual)
    end

    it "returns :conceptual for experimental" do
      expect(described_class.previous_status(:experimental)).to eq(:conceptual)
    end

    it "returns :experimental for alpha" do
      expect(described_class.previous_status(:alpha)).to eq(:experimental)
    end

    it "returns :alpha for beta" do
      expect(described_class.previous_status(:beta)).to eq(:alpha)
    end

    it "returns :beta for stable" do
      expect(described_class.previous_status(:stable)).to eq(:beta)
    end

    it "returns :stable for permanent" do
      expect(described_class.previous_status(:permanent)).to eq(:stable)
    end

    it "accepts string status names" do
      expect(described_class.previous_status("stable")).to eq(:beta)
    end
  end

  describe ".next_status" do
    it "returns the next automatically promoted status", :aggregate_failures do
      expect(described_class.next_status(:experimental)).to eq(:alpha)
      expect(described_class.next_status(:alpha)).to eq(:beta)
      expect(described_class.next_status(:beta)).to eq(:stable)
      expect(described_class.next_status("beta")).to eq(:stable)
    end

    it "returns nil for statuses outside automatic promotion", :aggregate_failures do
      expect(described_class.next_status(:conceptual)).to be_nil
      expect(described_class.next_status(:stable)).to be_nil
      expect(described_class.next_status(:permanent)).to be_nil
      expect(described_class.next_status(:never)).to be_nil
      expect(described_class.next_status(:unknown)).to be_nil
      expect(described_class.next_status(nil)).to be_nil
    end
  end

  describe ".history_for" do
    fab!(:admin)

    it "returns UserHistory records for the given setting" do
      UserHistory.create!(
        action: UserHistory.actions[:upcoming_change_toggled],
        subject: setting_name,
        acting_user_id: admin.id,
      )

      history = described_class.history_for(setting_name)

      expect(history.count).to eq(1)
      expect(history.first.subject).to eq(setting_name.to_s)
      expect(history.first.action).to eq(UserHistory.actions[:upcoming_change_toggled])
    end

    it "returns records ordered by created_at descending" do
      first_history =
        UserHistory.create!(
          action: UserHistory.actions[:upcoming_change_toggled],
          subject: setting_name,
          acting_user_id: admin.id,
          created_at: 2.days.ago,
        )

      second_history =
        UserHistory.create!(
          action: UserHistory.actions[:upcoming_change_toggled],
          subject: setting_name,
          acting_user_id: admin.id,
          created_at: 1.day.ago,
        )

      history = described_class.history_for(setting_name)

      expect(history.first.id).to eq(second_history.id)
      expect(history.last.id).to eq(first_history.id)
    end

    it "returns only records matching the setting name" do
      UserHistory.create!(
        action: UserHistory.actions[:upcoming_change_toggled],
        subject: setting_name,
        acting_user_id: admin.id,
      )

      UserHistory.create!(
        action: UserHistory.actions[:upcoming_change_toggled],
        subject: "different_setting",
        acting_user_id: admin.id,
      )

      history = described_class.history_for(setting_name)

      expect(history.count).to eq(1)
      expect(history.first.subject).to eq(setting_name.to_s)
    end

    it "returns only records with upcoming_change_toggled action" do
      UserHistory.create!(
        action: UserHistory.actions[:upcoming_change_toggled],
        subject: setting_name,
        acting_user_id: admin.id,
      )

      UserHistory.create!(
        action: UserHistory.actions[:change_site_setting],
        subject: setting_name,
        acting_user_id: admin.id,
      )

      history = described_class.history_for(setting_name)

      expect(history.count).to eq(1)
      expect(history.first.action).to eq(UserHistory.actions[:upcoming_change_toggled])
    end

    it "returns an empty relation when no history exists" do
      history = described_class.history_for("nonexistent_setting")

      expect(history.count).to eq(0)
      expect(history).to be_a(ActiveRecord::Relation)
    end
  end

  describe ".owning_plugin_configurable?" do
    let(:plugin_setting_name) { :enable_experimental_sample_plugin_feature }

    it "returns true for a core change with no owning plugin" do
      expect(described_class.owning_plugin_configurable?(setting_name)).to eq(true)
    end

    it "returns true when the owning plugin is configurable" do
      SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:configurable?).returns(true)

      expect(described_class.owning_plugin_configurable?(plugin_setting_name)).to eq(true)
    end

    it "returns false when the owning plugin is not configurable" do
      SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:configurable?).returns(false)

      expect(described_class.owning_plugin_configurable?(plugin_setting_name)).to eq(false)
    end

    it "returns true when the owning plugin has not been loaded yet" do
      Discourse.stubs(:plugins_by_name).returns({})

      expect(described_class.owning_plugin_configurable?(plugin_setting_name)).to eq(true)
    end
  end

  describe ".owning_plugin_enabled?" do
    let(:plugin_setting_name) { :enable_experimental_sample_plugin_feature }

    it "returns true for a core change with no owning plugin" do
      expect(described_class.owning_plugin_enabled?(setting_name)).to eq(true)
    end

    it "returns true when the owning plugin is enabled" do
      SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:enabled?).returns(true)

      expect(described_class.owning_plugin_enabled?(plugin_setting_name)).to eq(true)
    end

    it "returns false when the owning plugin is disabled" do
      SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:enabled?).returns(false)

      expect(described_class.owning_plugin_enabled?(plugin_setting_name)).to eq(false)
    end

    it "returns true when the owning plugin has not been loaded yet" do
      Discourse.stubs(:plugins_by_name).returns({})

      expect(described_class.owning_plugin_enabled?(plugin_setting_name)).to eq(true)
    end

    context "when the change is the owning plugin's own enabled_site_setting" do
      # e.g. discourse-workflows, whose enable_discourse_workflows setting is both
      # the plugin's on/off switch and an upcoming change. Plugin::Instance#enabled?
      # reads the ivar directly, so it has to be set rather than stubbed for these
      # examples to exercise the recursion the guard prevents.
      before do
        SiteSetting::SAMPLE_TEST_PLUGIN.instance_variable_set(
          :@enabled_site_setting,
          plugin_setting_name,
        )
      end

      after do
        SiteSetting::SAMPLE_TEST_PLUGIN.instance_variable_set(:@enabled_site_setting, nil)
        SiteSetting.remove_override!(plugin_setting_name)
        UpcomingChanges.clear_caches!
      end

      it "returns true rather than recursing through Plugin::Instance#enabled?" do
        expect(described_class.owning_plugin_enabled?(plugin_setting_name)).to eq(true)
      end

      it "keeps the change displayed while the plugin is off, since that row is how admins opt in" do
        expect(UpcomingChanges::ConditionalDisplay.should_display?(plugin_setting_name)).to eq(true)
      end

      it "still resolves the change normally" do
        expect(described_class.enabled?(plugin_setting_name)).to eq(false)

        SiteSetting.enable_experimental_sample_plugin_feature = true

        expect(described_class.enabled?(plugin_setting_name)).to eq(true)
      end
    end
  end

  describe ".enabled?" do
    after do
      SiteSetting.remove_override!(setting_name)
      SiteSetting.promote_upcoming_changes_on_status = :stable
      UpcomingChanges.clear_caches!
    end

    context "when the owning plugin is not configurable" do
      let(:plugin_setting_name) { :enable_experimental_sample_plugin_feature }

      before { SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:configurable?).returns(false) }

      it "returns false even when the change has been promoted" do
        SiteSetting.promote_upcoming_changes_on_status = :alpha

        expect(described_class.enabled?(plugin_setting_name)).to eq(false)
      end

      it "returns false even when the change is permanent" do
        mock_upcoming_change_metadata(
          { enable_experimental_sample_plugin_feature: { status: :permanent } },
        )

        expect(described_class.enabled?(plugin_setting_name)).to eq(false)
      end

      it "returns true again once the plugin becomes configurable" do
        SiteSetting.promote_upcoming_changes_on_status = :alpha
        SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:configurable?).returns(true)

        expect(described_class.enabled?(plugin_setting_name)).to eq(true)
      end
    end

    context "when the owning plugin is disabled" do
      let(:plugin_setting_name) { :enable_experimental_sample_plugin_feature }

      after do
        SiteSetting.remove_override!(plugin_setting_name)
        UpcomingChanges.clear_caches!
      end

      before { SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:enabled?).returns(false) }

      it "returns false even when the admin has opted in" do
        SiteSetting.enable_experimental_sample_plugin_feature = true

        expect(described_class.enabled?(plugin_setting_name)).to eq(false)
      end

      it "returns false even when the change has been promoted" do
        SiteSetting.promote_upcoming_changes_on_status = :alpha

        expect(described_class.enabled?(plugin_setting_name)).to eq(false)
      end

      it "returns false even when the change is permanent" do
        mock_upcoming_change_metadata(
          { enable_experimental_sample_plugin_feature: { status: :permanent } },
        )

        expect(described_class.enabled?(plugin_setting_name)).to eq(false)
      end

      it "keeps the admin's opt-in, so the change resolves again once the plugin is enabled" do
        SiteSetting.enable_experimental_sample_plugin_feature = true
        expect(described_class.enabled?(plugin_setting_name)).to eq(false)

        SiteSetting::SAMPLE_TEST_PLUGIN.unstub(:enabled?)

        expect(described_class.enabled?(plugin_setting_name)).to eq(true)
      end
    end

    context "when the change is not registered" do
      it "raises ArgumentError" do
        expect { described_class.enabled?(:not_an_upcoming_change) }.to raise_error(
          ArgumentError,
          /Unknown upcoming change/,
        )
      end
    end

    context "when the setting has no row in the database (admin has not saved it)" do
      before { SiteSetting.remove_override!(setting_name) }

      it "returns the yaml default when the change is below promote_upcoming_changes_on_status" do
        mock_upcoming_change_metadata(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :experimental,
              impact_type: "other",
              impact_role: "developers",
            },
          },
        )
        SiteSetting.promote_upcoming_changes_on_status = :stable

        expect(described_class.enabled?(setting_name)).to eq(SiteSetting.defaults[setting_name])
      end

      it "returns true when the change meets or exceeds promote_upcoming_changes_on_status" do
        mock_upcoming_change_metadata(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :stable,
              impact_type: "other",
              impact_role: "developers",
            },
          },
        )
        SiteSetting.promote_upcoming_changes_on_status = :stable

        expect(described_class.enabled?(setting_name)).to eq(true)
      end
    end

    context "when an admin has saved a value to the database" do
      it "returns the stored value when true" do
        SiteSetting.enable_upload_debug_mode = true

        expect(described_class.enabled?(setting_name)).to eq(true)
      end

      it "returns the stored value when false even when the change meets promote_upcoming_changes_on_status" do
        mock_upcoming_change_metadata(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :beta,
              impact_type: "other",
              impact_role: "developers",
            },
          },
        )
        SiteSetting.promote_upcoming_changes_on_status = :beta
        SiteSetting.enable_upload_debug_mode = false

        expect(described_class.enabled?(setting_name)).to eq(false)
      end
    end

    context "when the change is permanent" do
      before do
        mock_upcoming_change_metadata(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :permanent,
              impact_type: "other",
              impact_role: "developers",
            },
          },
        )
      end

      it "returns true even when the database value is false" do
        SiteSetting.enable_upload_debug_mode = false

        expect(described_class.enabled?(setting_name)).to eq(true)
      end
    end
  end

  # Models the self-hoster upgrade that lowers the default
  # promote_upcoming_changes_on_status from :stable to :beta. A beta change
  # that previously sat below the promotion threshold now meets it, so we must
  # be sure the transition only auto-promotes changes the admin never touched
  # and never overrides an admin's explicit opt-in/opt-out. The opt-out case is
  # the critical one: the stored value equals the YAML default (false), and it
  # only survives because setting_modified_from_default? treats upcoming change
  # settings as modified whenever a DB row exists (see SiteSettingExtension#refresh!).
  describe "lowering promote_upcoming_changes_on_status from :stable to :beta" do
    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :beta,
            impact_type: "other",
            impact_role: "developers",
          },
        },
      )
      SiteSetting.promote_upcoming_changes_on_status = :stable
      UpcomingChanges.clear_caches!
    end

    after do
      SiteSetting.remove_override!(setting_name)
      SiteSetting.promote_upcoming_changes_on_status = :stable
      UpcomingChanges.clear_caches!
    end

    it "auto-promotes a change the admin never touched" do
      expect(described_class.enabled?(setting_name)).to eq(false)

      SiteSetting.promote_upcoming_changes_on_status = :beta

      expect(described_class.enabled?(setting_name)).to eq(true)
    end

    it "keeps a change the admin explicitly opted out of disabled" do
      SiteSetting.enable_upload_debug_mode = false
      expect(described_class.enabled?(setting_name)).to eq(false)

      SiteSetting.promote_upcoming_changes_on_status = :beta

      expect(described_class.enabled?(setting_name)).to eq(false)
    end

    it "keeps a change the admin explicitly opted into enabled" do
      SiteSetting.enable_upload_debug_mode = true
      expect(described_class.enabled?(setting_name)).to eq(true)

      SiteSetting.promote_upcoming_changes_on_status = :beta

      expect(described_class.enabled?(setting_name)).to eq(true)
    end
  end

  describe ".change_dependencies_met?" do
    it "returns true for a change with no dependencies" do
      expect(described_class.change_dependencies_met?(:enable_upload_debug_mode)).to eq(true)
    end

    it "returns false when a boolean dependency is disabled" do
      SiteSetting.allow_user_locale = false

      expect(described_class.change_dependencies_met?(:set_locale_from_cookie)).to eq(false)
    end

    it "returns true when all boolean dependencies are enabled" do
      SiteSetting.allow_user_locale = true

      expect(described_class.change_dependencies_met?(:set_locale_from_cookie)).to eq(true)
    end

    context "with depends_on_values for a non-boolean dependency" do
      before do
        SiteSetting
          .type_supervisor
          .dependencies
          .stubs(:[])
          .with(:fake_change)
          .returns([:desktop_category_page_style])
        SiteSetting.stubs(:dependency_values).returns(
          { fake_change: { desktop_category_page_style: %w[categories_only] } },
        )
      end

      it "returns true when the dependency matches an allowed value" do
        SiteSetting.desktop_category_page_style = "categories_only"

        expect(described_class.change_dependencies_met?(:fake_change)).to eq(true)
      end

      it "returns false when the dependency does not match an allowed value" do
        SiteSetting.desktop_category_page_style = "categories_and_latest_topics"

        expect(described_class.change_dependencies_met?(:fake_change)).to eq(false)
      end
    end
  end

  describe ".settings_hidden_while_enabled" do
    # `enable_upload_debug_mode` stands in for the change; the two real settings
    # below stand in for the legacy settings it would hide.
    let(:hidden_setting_names) { %i[allow_uncategorized_topics suppress_uncategorized_badge] }

    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
            hide_settings: hidden_setting_names,
          },
        },
      )
    end

    after do
      SiteSetting.remove_override!(setting_name)
      UpcomingChanges.clear_caches!
    end

    it "returns nothing when the change is not enabled" do
      SiteSetting.remove_override!(setting_name)

      expect(described_class.settings_hidden_while_enabled).to be_empty
    end

    it "returns the declared settings when the change is enabled" do
      SiteSetting.enable_upload_debug_mode = true

      expect(described_class.settings_hidden_while_enabled).to contain_exactly(
        *hidden_setting_names,
      )
    end

    it "ignores changes that do not declare hide_settings" do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
          },
        },
      )
      SiteSetting.enable_upload_debug_mode = true

      expect(described_class.settings_hidden_while_enabled).to be_empty
    end

    context "when the change is owned by a plugin the admin has opted into and then disabled" do
      let(:plugin_setting_name) { :enable_experimental_sample_plugin_feature }

      before do
        mock_upcoming_change_metadata(
          {
            enable_experimental_sample_plugin_feature: {
              impact: "feature,all_members",
              status: :experimental,
              impact_type: "feature",
              impact_role: "all_members",
              hide_settings: hidden_setting_names,
            },
          },
        )
        SiteSetting.enable_experimental_sample_plugin_feature = true
      end

      after do
        SiteSetting.remove_override!(plugin_setting_name)
        UpcomingChanges.clear_caches!
      end

      it "hides the declared settings while the plugin is enabled" do
        expect(described_class.settings_hidden_while_enabled).to contain_exactly(
          *hidden_setting_names,
        )
      end

      it "stops hiding them once the plugin is disabled, so the change leaves nothing behind" do
        SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:enabled?).returns(false)

        expect(described_class.settings_hidden_while_enabled).to be_empty
      end
    end

    it "feeds SiteSetting.hidden_settings so the settings are hidden while enabled" do
      expect(SiteSetting.hidden_settings).not_to include(*hidden_setting_names)

      SiteSetting.enable_upload_debug_mode = true

      expect(SiteSetting.hidden_settings).to include(*hidden_setting_names)
    end
  end

  describe ".enabled_for_with_groups" do
    let(:setting_name) { :enable_upload_debug_mode }
    let(:groups_hash) { { Group::AUTO_GROUPS[:staff] => "staff" } }

    def mock_allow(allow)
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
            allow_enabled_for: allow,
          },
        },
      )
    end

    context "when the setting is disabled" do
      it "returns no_one" do
        result = described_class.enabled_for_with_groups(setting_name, false, groups_hash)
        expect(result[:enabled_for]).to eq("no_one")
      end
    end

    context "when the setting is enabled with no admin-configured groups" do
      context "when allow_enabled_for is omitted" do
        it "returns everyone" do
          result = described_class.enabled_for_with_groups(setting_name, true, groups_hash)
          expect(result[:enabled_for]).to eq("everyone")
        end
      end

      context "when allow_enabled_for is [everyone]" do
        before { mock_allow([:everyone]) }

        it "returns everyone" do
          result = described_class.enabled_for_with_groups(setting_name, true, groups_hash)
          expect(result[:enabled_for]).to eq("everyone")
        end
      end

      context "when allow_enabled_for is [staff, specific_groups]" do
        before { mock_allow(%i[staff specific_groups]) }

        it "returns the staff group name as the broadest allowed display target" do
          result = described_class.enabled_for_with_groups(setting_name, true, groups_hash)
          expect(result[:enabled_for]).to eq("staff")
        end
      end

      context "when allow_enabled_for is [staff]" do
        before { mock_allow([:staff]) }

        it "returns the staff group name" do
          result = described_class.enabled_for_with_groups(setting_name, true, groups_hash)
          expect(result[:enabled_for]).to eq("staff")
        end
      end

      context "when allow_enabled_for is [specific_groups]" do
        before { mock_allow([:specific_groups]) }

        it "returns groups" do
          result = described_class.enabled_for_with_groups(setting_name, true, groups_hash)
          expect(result[:enabled_for]).to eq("groups")
        end
      end
    end
  end

  describe ".current_statuses" do
    include ActiveSupport::Testing::TimeHelpers

    before { described_class.clear_caches! }

    after do
      described_class.clear_caches!
      UpcomingChangeEvent.where(upcoming_change_name: "timeline_status_setting").delete_all
    end

    it "returns an empty hash when there are no status_changed events" do
      expect(described_class.current_statuses).to eq({})
    end

    it "maps each upcoming change to the latest status_changed new_value and timestamp" do
      travel_to Time.zone.parse("2024-06-01 12:00:00") do
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: "timeline_status_setting",
          event_data: {
            "previous_value" => "alpha",
            "new_value" => "beta",
          },
        )
      end

      latest_event =
        travel_to(Time.zone.parse("2024-06-15 12:00:00")) do
          UpcomingChangeEvent.create!(
            event_type: :status_changed,
            upcoming_change_name: "timeline_status_setting",
            event_data: {
              "previous_value" => "beta",
              "new_value" => "stable",
            },
          )
        end

      result = described_class.current_statuses

      expect(result["timeline_status_setting"]).to eq(
        { status: "stable", changed_at: latest_event.created_at },
      )
    end

    it "caches the result so the SQL runs only once until the cache key is deleted" do
      UpcomingChangeEvent.create!(
        event_type: :status_changed,
        upcoming_change_name: "timeline_status_setting",
        event_data: {
          "previous_value" => nil,
          "new_value" => "experimental",
        },
      )

      allow(DB).to receive(:query).and_call_original

      2.times { described_class.current_statuses }
      expect(DB).to have_received(:query).once

      described_class.clear_caches!

      described_class.current_statuses
      expect(DB).to have_received(:query).twice
    end
  end

  describe ".permanent_upcoming_changes" do
    before do
      described_class.clear_caches!
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :permanent,
            impact_type: "other",
            impact_role: "developers",
          },
        },
      )
    end

    after { described_class.clear_caches! }

    it "returns only changes whose metadata status is permanent" do
      list = described_class.permanent_upcoming_changes

      expect(list.all? { |c| described_class.change_status(c[:setting]) == :permanent }).to eq(true)
      expect(list.map { |c| c[:setting] }).to include(:enable_upload_debug_mode)
    end

    it "caches the list so UpcomingChanges::List runs only once until the cache key is deleted" do
      allow(UpcomingChanges::List).to receive(:call).and_call_original

      2.times { described_class.permanent_upcoming_changes }
      expect(UpcomingChanges::List).to have_received(:call).once

      described_class.clear_caches!

      described_class.permanent_upcoming_changes
      expect(UpcomingChanges::List).to have_received(:call).twice
    end
  end

  describe ".clear_caches!" do
    it "clears the latest new feature created_at cache" do
      Discourse.redis.set("latest_new_feature_created_at", Time.zone.now.iso8601)
      described_class.clear_caches!
      expect(Discourse.redis.get("latest_new_feature_created_at")).to be_nil
    end
  end

  describe ".enabled_for_user?" do
    context "for logged-in user" do
      fab!(:user)

      context "when the upcoming change is disabled" do
        before { SiteSetting.enable_upload_debug_mode = false }

        it "returns false" do
          expect(UpcomingChanges.enabled_for_user?(setting_name, user)).to eq(false)
        end
      end

      context "when the upcoming change is enabled for everyone" do
        before { SiteSetting.enable_upload_debug_mode = true }

        it "returns true" do
          expect(UpcomingChanges.enabled_for_user?(setting_name, user)).to eq(true)
        end
      end

      context "when the upcoming change is only enabled for certain groups" do
        before do
          SiteSetting.enable_upload_debug_mode = true
          Fabricate(
            :site_setting_group,
            name: setting_name,
            group_ids: Group::AUTO_GROUPS[:trust_level_4].to_s,
          )
        end

        it "returns false" do
          expect(UpcomingChanges.enabled_for_user?(setting_name, user)).to eq(false)
        end

        context "when the user is in that group" do
          before do
            trust_level_4_group = Group.find_by(id: Group::AUTO_GROUPS[:trust_level_4])
            trust_level_4_group.add(user)
          end

          it "returns true" do
            expect(UpcomingChanges.enabled_for_user?(setting_name, user)).to eq(true)
          end
        end
      end
    end

    context "for anonymous user" do
      let(:user) { nil }

      context "when the upcoming change is disabled" do
        before { SiteSetting.enable_upload_debug_mode = false }

        it "returns false" do
          expect(UpcomingChanges.enabled_for_user?(setting_name, user)).to eq(false)
        end
      end

      context "when the upcoming change is enabled for everyone" do
        before { SiteSetting.enable_upload_debug_mode = true }

        it "returns true" do
          expect(UpcomingChanges.enabled_for_user?(setting_name, user)).to eq(true)
        end
      end

      context "when the upcoming change is only enabled for certain groups" do
        before do
          SiteSetting.enable_upload_debug_mode = true
          Fabricate(
            :site_setting_group,
            name: setting_name,
            group_ids: Group::AUTO_GROUPS[:trust_level_4].to_s,
          )
        end

        it "returns false" do
          expect(UpcomingChanges.enabled_for_user?(setting_name, user)).to eq(false)
        end
      end
    end
  end

  describe "conceptual status filtering" do
    it "excludes conceptual changes from all_settings with only_upcoming_changes" do
      settings =
        SiteSetting
          .all_settings(only_upcoming_changes: true, include_hidden: true)
          .map { |s| s[:setting] }
      expect(settings).not_to include(:conceptual_setting)
      expect(settings).to include(:enable_upload_debug_mode)
    end
  end

  describe "conditional display" do
    after do
      DiscoursePluginRegistry.reset_register!(:upcoming_change_conditional_display_callbacks)
    end

    it "returns true when the conditional display method is undefined for an upcoming change" do
      expect(UpcomingChanges::ConditionalDisplay.should_display?(:enable_upload_debug_mode)).to eq(
        true,
      )
    end

    it "returns true when the registered callback returns true" do
      Plugin::Instance
        .new
        .register_upcoming_change_conditional_display(:enable_upload_debug_mode) { true }

      expect(UpcomingChanges::ConditionalDisplay.should_display?(:enable_upload_debug_mode)).to eq(
        true,
      )
    end

    it "returns false when the registered callback returns false" do
      Plugin::Instance
        .new
        .register_upcoming_change_conditional_display(:enable_upload_debug_mode) { false }

      expect(UpcomingChanges::ConditionalDisplay.should_display?(:enable_upload_debug_mode)).to eq(
        false,
      )
    end

    it "returns false when any registered callback returns false" do
      Plugin::Instance
        .new
        .register_upcoming_change_conditional_display(:enable_upload_debug_mode) { true }
      Plugin::Instance
        .new
        .register_upcoming_change_conditional_display(:enable_upload_debug_mode) { false }

      expect(UpcomingChanges::ConditionalDisplay.should_display?(:enable_upload_debug_mode)).to eq(
        false,
      )
    end

    it "ignores callbacks from disabled plugins" do
      plugin = Plugin::Instance.new
      plugin.stubs(:enabled?).returns(false)
      plugin.register_upcoming_change_conditional_display(:enable_upload_debug_mode) { false }

      expect(UpcomingChanges::ConditionalDisplay.should_display?(:enable_upload_debug_mode)).to eq(
        true,
      )
    end

    context "when the owning plugin is disabled" do
      let(:plugin_setting_name) { :enable_experimental_sample_plugin_feature }

      before { SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:enabled?).returns(false) }

      it "returns false" do
        expect(UpcomingChanges::ConditionalDisplay.should_display?(plugin_setting_name)).to eq(
          false,
        )
      end

      it "returns false even when the plugin registered a conditional display callback" do
        SiteSetting::SAMPLE_TEST_PLUGIN.register_upcoming_change_conditional_display(
          plugin_setting_name,
        ) { true }

        expect(UpcomingChanges::ConditionalDisplay.should_display?(plugin_setting_name)).to eq(
          false,
        )
      end
    end

    context "when the owning plugin is not configurable" do
      let(:plugin_setting_name) { :enable_experimental_sample_plugin_feature }

      it "returns false" do
        SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:configurable?).returns(false)

        expect(UpcomingChanges::ConditionalDisplay.should_display?(plugin_setting_name)).to eq(
          false,
        )
      end

      it "returns false without consulting the change's conditional display method" do
        SiteSetting::SAMPLE_TEST_PLUGIN.stubs(:configurable?).returns(false)
        UpcomingChanges::ConditionalDisplay.define_singleton_method(
          :should_display_enable_experimental_sample_plugin_feature?,
        ) { raise "should not be called" }

        begin
          expect(UpcomingChanges::ConditionalDisplay.should_display?(plugin_setting_name)).to eq(
            false,
          )
        ensure
          UpcomingChanges::ConditionalDisplay.singleton_class.send(
            :remove_method,
            :should_display_enable_experimental_sample_plugin_feature?,
          )
        end
      end
    end

    context "when the conditional display method is defined for an upcoming change" do
      context "when the conditional display method returns true" do
        before do
          UpcomingChanges::ConditionalDisplay.define_singleton_method(
            :should_display_enable_upload_debug_mode?,
          ) { true }
        end

        after do
          UpcomingChanges::ConditionalDisplay.singleton_class.send(
            :remove_method,
            :should_display_enable_upload_debug_mode?,
          )
        end

        it "returns true" do
          expect(
            UpcomingChanges::ConditionalDisplay.should_display?(:enable_upload_debug_mode),
          ).to eq(true)
        end

        it "takes precedence over registered callbacks" do
          Plugin::Instance
            .new
            .register_upcoming_change_conditional_display(:enable_upload_debug_mode) { false }

          expect(
            UpcomingChanges::ConditionalDisplay.should_display?(:enable_upload_debug_mode),
          ).to eq(true)
        end
      end

      context "when the conditional display method returns false" do
        before do
          UpcomingChanges::ConditionalDisplay.define_singleton_method(
            :should_display_enable_upload_debug_mode?,
          ) { false }
        end

        after do
          UpcomingChanges::ConditionalDisplay.singleton_class.send(
            :remove_method,
            :should_display_enable_upload_debug_mode?,
          )
        end

        it "returns false" do
          expect(
            UpcomingChanges::ConditionalDisplay.should_display?(:enable_upload_debug_mode),
          ).to eq(false)
        end
      end
    end

    describe ".should_display_enable_local_logins_via_code?" do
      it "returns true when local logins via email are possible" do
        expect(
          UpcomingChanges::ConditionalDisplay.should_display?(:enable_local_logins_via_code),
        ).to eq(true)
      end

      it "returns false when DiscourseConnect is enabled" do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.discourse_connect_secret = "x" * 10
        SiteSetting.enable_discourse_connect = true

        expect(
          UpcomingChanges::ConditionalDisplay.should_display?(:enable_local_logins_via_code),
        ).to eq(false)
      end

      it "returns false when local logins via email are disabled" do
        SiteSetting.enable_local_logins_via_email = false

        expect(
          UpcomingChanges::ConditionalDisplay.should_display?(:enable_local_logins_via_code),
        ).to eq(false)
      end

      it "stays displayed when the change is already enabled even if email login is later disabled" do
        SiteSetting.enable_local_logins_via_code = true
        SiteSetting.enable_local_logins_via_email = false

        expect(
          UpcomingChanges::ConditionalDisplay.should_display?(:enable_local_logins_via_code),
        ).to eq(true)
      end
    end
  end
end
