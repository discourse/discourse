# frozen_string_literal: true

RSpec.describe UpcomingChanges::List do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:params) { {} }

    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :pre_alpha,
            impact_type: "other",
            impact_role: "developers",
          },
        },
      )
    end

    context "when a non-admin user tries to list upcoming changes" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "has all the necessary data for the change" do
        results = result.upcoming_changes
        mock_setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }

        expect(mock_setting).to include(
          setting: :enable_upload_debug_mode,
          humanized_name: "Enable upload debug mode",
          description: "",
          value: SiteSetting.enable_upload_debug_mode,
          upcoming_change: {
            impact: "other,developers",
            impact_role: "developers",
            impact_type: "other",
            status: :pre_alpha,
          },
        )
      end

      it "includes the image_url if there is an image for the change in public/images" do
        Rails.stubs(:public_path).returns(File.join(Rails.root, "spec", "fixtures"))

        results = result.upcoming_changes
        mock_setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }
        expect(mock_setting[:upcoming_change][:image]).to eq(
          {
            url: "#{Discourse.base_url}/#{UpcomingChanges.image_path(mock_setting[:setting])}",
            width: 244,
            height: 66,
          },
        )
      end

      # NOTE (martin): Skipped for now because it is flaky on CI, it will be something to do with the
      # sample plugin settings loaded in the SiteSetting model.
      xit "includes the plugin name if the setting is from a plugin" do
        results = result.upcoming_changes
        sample_plugin_setting =
          results.find { |change| change[:setting] == :enable_experimental_sample_plugin_feature }
        expect(sample_plugin_setting[:plugin]).to eq("Sample plugin")
      end

      it "includes the group names if there are site setting group IDs for the change" do
        SiteSettingGroup.create!(name: "enable_upload_debug_mode", group_ids: "10|11")
        SiteSetting.refresh!
        results = result.upcoming_changes
        mock_setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }

        expect(mock_setting[:groups]).to eq(%w[trust_level_0 trust_level_1])
      end
    end
  end
end
