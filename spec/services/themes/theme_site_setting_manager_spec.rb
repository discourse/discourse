# frozen_string_literal: true

# TODO (martin) Refactor this to follow updated spec patterns for services
RSpec.describe Themes::ThemeSiteSettingManager do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(guardian:, params:) }

    let(:guardian) { admin.guardian }

    fab!(:admin)
    fab!(:theme)

    let(:params) { { theme_id: theme.id, name: "enable_welcome_banner", value: false } }

    before { SiteSetting.refresh! }

    context "when a non-admin user tries to change a setting" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the site setting is not a themeable one" do
      let(:params) { { theme_id: theme.id, name: "title", value: "New Title" } }

      it { is_expected.to fail_a_policy(:ensure_setting_is_themeable) }
    end

    context "when creating a new theme site setting" do
      it "runs successfully" do
        expect(result).to be_a_success
      end

      it "creates a new theme site setting" do
        expect { result }.to change { ThemeSiteSetting.count }.by(1)

        theme_site_setting = ThemeSiteSetting.last
        expect(theme_site_setting.theme_id).to eq(theme.id)
        expect(theme_site_setting.name).to eq("enable_welcome_banner")
        expect(theme_site_setting.value).to eq("f")
        expect(theme_site_setting.data_type).to eq(SiteSetting.types[:bool])
      end

      it "logs the creation in staff action log" do
        StaffActionLogger
          .any_instance
          .expects(:log_theme_site_setting_change)
          .with(:enable_welcome_banner, nil, false, theme)
        expect(result).to be_a_success
      end

      it "refreshes the value in the SiteSetting cache" do
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(true)
        expect(result).to be_a_success
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(false)
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
        expect(event[:params]).to eq([:enable_welcome_banner, nil, false])
      end
    end

    context "when updating an existing theme site setting" do
      fab!(:theme_site_setting) do
        Fabricate(
          :theme_site_setting_with_service,
          theme: theme,
          name: "enable_welcome_banner",
          value: true,
        )
      end

      it "runs successfully" do
        expect(result).to be_a_success
      end

      it "updates the existing theme site setting" do
        expect { result }.not_to change { ThemeSiteSetting.count }

        theme_site_setting.reload
        expect(theme_site_setting.value).to eq("f")
      end

      it "logs the creation in staff action log" do
        StaffActionLogger
          .any_instance
          .expects(:log_theme_site_setting_change)
          .with(:enable_welcome_banner, true, false, theme)
        expect(result).to be_a_success
      end

      it "refreshes the value in the SiteSetting cache" do
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(true)
        expect(result).to be_a_success
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(false)
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

      it "runs successfully" do
        expect(result).to be_a_success
      end

      it "removes the theme site setting" do
        expect { result }.to change { ThemeSiteSetting.count }.by(-1)
        expect(ThemeSiteSetting.find_by(id: theme_site_setting.id)).to be_nil
      end

      it "logs the removal in staff action log" do
        StaffActionLogger
          .any_instance
          .expects(:log_theme_site_setting_change)
          .with(:enable_welcome_banner, false, true, theme)
        expect(result).to be_a_success
      end

      it "refreshes the value in the SiteSetting cache" do
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(false)
        expect(result).to be_a_success
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(true)
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

        expect(event).to be_present
        expect(event[:params]).to eq([:enable_welcome_banner, false, true])
      end
    end

    context "when setting value to the same as the site setting default" do
      let!(:theme_site_setting) do
        Fabricate(
          :theme_site_setting_with_service,
          theme: theme,
          name: "enable_welcome_banner",
          value: true,
        )
      end

      let(:params) { { theme_id: theme.id, name: "enable_welcome_banner", value: true } }

      it "runs successfully" do
        expect(result).to be_a_success
      end

      it "removes the theme site setting when value matches default" do
        expect { result }.to change { ThemeSiteSetting.count }.by(-1)
        expect(ThemeSiteSetting.find_by(id: theme_site_setting.id)).to be_nil
      end
    end

    context "when theme doesn't exist" do
      before { theme.destroy! }

      it "fails to find the theme" do
        expect(result).to fail_to_find_a_model(:theme)
      end
    end
  end
end
