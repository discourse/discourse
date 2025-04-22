# frozen_string_literal: true

RSpec.describe Themes::ThemeSiteSettingUpsert do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(guardian: admin.guardian, params:) }

    fab!(:admin)
    fab!(:theme)

    let(:params) { { theme_id: theme.id, name: "enable_welcome_banner", value: false } }

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
          .with("enable_welcome_banner", nil, "f", theme)
        expect(result).to be_a_success
      end

      it "refreshes the value in the SiteSetting cache" do
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(true)
        expect(result).to be_a_success
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(false)
      end
    end

    context "when updating an existing theme site setting" do
      fab!(:theme_site_setting) do
        Fabricate(:theme_site_setting, theme: theme, name: "enable_welcome_banner", value: true)
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
          .with("enable_welcome_banner", "t", "f", theme)
        expect(result).to be_a_success
      end

      it "refreshes the value in the SiteSetting cache" do
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(true)
        expect(result).to be_a_success
        expect(SiteSetting.enable_welcome_banner(theme_id: theme.id)).to eq(false)
      end
    end

    context "when removing a theme site setting by ommitting the value" do
      let!(:theme_site_setting) do
        Fabricate(
          :theme_site_setting,
          theme: theme,
          name: "enable_welcome_banner",
          value: "Old Theme Title",
        )
      end

      let(:params) { { theme_id: theme.id, name: "enable_welcome_banner", value: nil } }

      it "runs successfully" do
        expect(result).to be_a_success
      end

      it "removes the theme site setting" do
        expect { result }.to change { ThemeSiteSetting.count }.by(-1)
        expect(ThemeSiteSetting.find_by(id: theme_site_setting.id)).to be_nil
      end
    end

    context "when setting value to the same as the site setting default" do
      let!(:theme_site_setting) do
        Fabricate(:theme_site_setting, theme: theme, name: "enable_welcome_banner", value: true)
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

    # context "with different data types" do
    #   context "with integer setting" do
    #     let(:params) { { theme_id: theme.id, name: "min_post_length", value: "20" } }

    #     before do
    #       SiteSetting.stubs(:types).returns({ integer: 1 })
    #       SiteSetting.stubs(:type_supervisor).returns(stub(to_db_value: ["20", 1], to_rb_value: 20))
    #     end

    #     it "runs successfully" do
    #       expect(result).to be_a_success
    #     end

    #     it "converts the value to the correct type" do
    #       result
    #       theme_site_setting = ThemeSiteSetting.last
    #       expect(theme_site_setting.data_type).to eq(1) # integer type
    #       expect(theme_site_setting.value).to eq("20")
    #     end
    #   end

    #   context "with boolean setting" do
    #     let(:params) { { theme_id: theme.id, name: "allow_uncategorized_topics", value: "false" } }

    #     before do
    #       SiteSetting.stubs(:types).returns({ boolean: 2 })
    #       SiteSetting.stubs(:type_supervisor).returns(
    #         stub(to_db_value: ["false", 2], to_rb_value: false),
    #       )
    #     end

    #     it "runs successfully" do
    #       expect(result).to be_a_success
    #     end

    #     it "converts the value to the correct type" do
    #       result
    #       theme_site_setting = ThemeSiteSetting.last
    #       expect(theme_site_setting.data_type).to eq(2) # boolean type
    #       expect(theme_site_setting.value).to eq("false")
    #     end
    #   end
    # end

    context "when theme doesn't exist" do
      before { theme.destroy! }

      it "fails to find the theme" do
        expect(result).to fail_to_find_a_model(:theme)
      end
    end
  end
end
