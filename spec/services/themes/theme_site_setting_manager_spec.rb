# frozen_string_literal: true

RSpec.describe Themes::ThemeSiteSettingManager do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(guardian:, params:) }

    fab!(:admin)
    fab!(:theme)

    let(:guardian) { admin.guardian }
    let(:params) { { theme_id: theme.id, name: "enable_welcome_banner", value: false } }

    before { SiteSetting.refresh! }

    context "when data is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when a non-admin user tries to change a setting" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the site setting is not a themeable one" do
      let(:params) { { theme_id: theme.id, name: "title", value: "New Title" } }

      it { is_expected.to fail_a_policy(:ensure_setting_is_themeable) }
    end

    context "when theme doesn't exist" do
      before { theme.destroy! }

      it "fails to find the theme" do
        expect(result).to fail_to_find_a_model(:theme)
      end
    end

    context "when creating a new theme site setting" do
      it { is_expected.to run_successfully }

      it "creates a new theme site setting" do
        expect { result }.to change { ThemeSiteSetting.count }.by(1)

        theme_site_setting = ThemeSiteSetting.last
        expect(theme_site_setting).to have_attributes(
          theme_id: theme.id,
          name: "enable_welcome_banner",
          value: "f",
          data_type: SiteSetting.types[:bool],
        )
      end

      it "logs the creation in staff action log" do
        StaffActionLogger
          .any_instance
          .expects(:log_theme_site_setting_change)
          .with(:enable_welcome_banner, nil, false, theme)
        result
      end

      it "refreshes the value in the SiteSetting cache" do
        expect { result }.to change { SiteSetting.enable_welcome_banner(theme_id: theme.id) }.from(
          true,
        ).to(false)
      end

      it "should publish changes to clients for client site settings" do
        message = MessageBus.track_publish("/client_settings") { result }.first
        expect(message.data).to eq(
          { name: :enable_welcome_banner, scoped_to: { theme_id: theme.id }, value: false },
        )
      end

      it "sends a DiscourseEvent for the change" do
        event =
          DiscourseEvent
            .track_events { messages = MessageBus.track_publish { result } }
            .find { |e| e[:event_name] == :theme_site_setting_changed }

        expect(event).to be_present
        expect(event[:params]).to eq([:enable_welcome_banner, true, false])
      end
    end

    context "when updating an existing theme site setting" do
      fab!(:theme_site_setting) do
        # NOTE: This example is a little contrived, because `true` is the same as the site setting default,
        # it would usually not ever be inserted into ThemeSiteSetting.
        #
        # However, we don't have any theme site settings yet with an enum with > 2 choices,
        # so we have to fake things a bit here to make sure the update behaviour works.
        Fabricate(:theme_site_setting, theme: theme, name: "enable_welcome_banner", value: true)
      end

      it { is_expected.to run_successfully }

      it "updates the existing theme site setting" do
        expect { result }.not_to change { ThemeSiteSetting.count }
        expect(theme_site_setting.reload.value).to eq("f")
      end

      it "logs the creation in staff action log" do
        StaffActionLogger
          .any_instance
          .expects(:log_theme_site_setting_change)
          .with(:enable_welcome_banner, true, false, theme)
        result
      end

      it "refreshes the value in the SiteSetting cache" do
        expect { result }.to change { SiteSetting.enable_welcome_banner(theme_id: theme.id) }.from(
          true,
        ).to(false)
      end

      it "should publish changes to clients for client site settings" do
        message = MessageBus.track_publish("/client_settings") { result }.first
        expect(message.data).to eq(
          { name: :enable_welcome_banner, scoped_to: { theme_id: theme.id }, value: false },
        )
      end

      it "sends a DiscourseEvent for the change" do
        event =
          DiscourseEvent
            .track_events { messages = MessageBus.track_publish { result } }
            .find { |e| e[:event_name] == :theme_site_setting_changed }

        expect(event[:params]).to eq([:enable_welcome_banner, true, false])
      end
    end

    context "when removing a theme site setting by ommitting the value" do
      let!(:theme_site_setting) do
        Fabricate(
          :theme_site_setting_with_service,
          theme: theme,
          name: "enable_welcome_banner",
          value: false,
        )
      end

      before { SiteSetting.refresh! }

      let(:params) { { theme_id: theme.id, name: "enable_welcome_banner", value: nil } }

      it { is_expected.to run_successfully }

      it "updates the theme site setting to the site setting default value" do
        result
        expect(theme_site_setting.reload.value).to eq("t")
      end

      it "logs the removal in staff action log" do
        StaffActionLogger
          .any_instance
          .expects(:log_theme_site_setting_change)
          .with(:enable_welcome_banner, false, true, theme)
        result
      end

      it "refreshes the value in the SiteSetting cache" do
        expect { result }.to change { SiteSetting.enable_welcome_banner(theme_id: theme.id) }.from(
          false,
        ).to(true)
      end

      it "should publish changes to clients for client site settings" do
        message = MessageBus.track_publish("/client_settings") { result }.first
        expect(message.data).to eq(
          { name: :enable_welcome_banner, scoped_to: { theme_id: theme.id }, value: true },
        )
      end

      it "sends a DiscourseEvent for the change" do
        event =
          DiscourseEvent
            .track_events { messages = MessageBus.track_publish { result } }
            .find { |e| e[:event_name] == :theme_site_setting_changed }

        expect(event[:params]).to eq([:enable_welcome_banner, false, true])
      end
    end

    context "when changing value to the same as the site setting default" do
      let!(:theme_site_setting) do
        Fabricate(
          :theme_site_setting_with_service,
          theme: theme,
          name: "enable_welcome_banner",
          value: false,
        )
      end

      let(:params) { { theme_id: theme.id, name: "enable_welcome_banner", value: true } }

      it { is_expected.to run_successfully }

      it "updates theme site setting when value matches default" do
        result
        expect(theme_site_setting.reload.value).to eq("t")
      end
    end
  end
end
