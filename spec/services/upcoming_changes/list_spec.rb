# frozen_string_literal: true

RSpec.describe UpcomingChanges::List do
  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:admin)
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:options) { {} }
    let(:params) { {} }

    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
          },
          allow_user_locale: {
            impact: "feature,all_members",
            status: :beta,
            impact_type: "feature",
            impact_role: "all_members",
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
        )

        expect(mock_setting[:upcoming_change]).to include(
          impact: "other,developers",
          impact_role: "developers",
          impact_type: "other",
          status: :experimental,
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

      it "includes the plugin name if the setting is from a plugin" do
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

        expect(mock_setting[:groups]).to eq("trust_level_0,trust_level_1")
      end

      describe "overriding defaults setting" do
        context "when an upcoming_change_default_override points to the change" do
          before do
            mock_upcoming_change_default_overrides(
              {
                suggested_topics_max_days_old: {
                  upcoming_change: :enable_upload_debug_mode,
                  new_default: 1000,
                },
              },
            )
          end

          it "includes overriding_defaults as true" do
            results = result.upcoming_changes
            mock_setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }
            expect(mock_setting[:overriding_defaults]).to eq(true)
          end
        end

        it "returns false for overriding_defaults when no upcoming_change_default_override points to the change" do
          results = result.upcoming_changes
          mock_setting = results.find { |change| change[:setting] == :allow_user_locale }
          expect(mock_setting[:overriding_defaults]).to eq(false)
        end
      end

      describe "enabled_for logic" do
        it "sets enabled_for to 'no_one' when setting value is false" do
          SiteSetting.enable_upload_debug_mode = false
          results = result.upcoming_changes
          mock_setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }

          expect(mock_setting[:upcoming_change][:enabled_for]).to eq("no_one")
        end

        it "sets enabled_for to 'everyone' when setting value is true and groups are empty" do
          SiteSetting.enable_upload_debug_mode = true
          SiteSettingGroup.create!(name: "enable_upload_debug_mode", group_ids: "")
          SiteSetting.refresh_site_setting_group_ids!
          SiteSetting.notify_changed!

          results = result.upcoming_changes
          mock_setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }

          expect(mock_setting[:upcoming_change][:enabled_for]).to eq("everyone")
        end

        it "sets enabled_for to 'staff' when setting value is true and group is only staff" do
          SiteSetting.enable_upload_debug_mode = true
          SiteSettingGroup.create!(
            name: "enable_upload_debug_mode",
            group_ids: Group::AUTO_GROUPS[:staff].to_s,
          )
          SiteSetting.refresh_site_setting_group_ids!
          SiteSetting.notify_changed!

          results = result.upcoming_changes
          mock_setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }

          expect(mock_setting[:upcoming_change][:enabled_for]).to eq("staff")
        end

        it "sets enabled_for to 'groups' when setting value is true and has specific groups" do
          SiteSetting.enable_upload_debug_mode = true
          SiteSettingGroup.create!(name: "enable_upload_debug_mode", group_ids: "10|11")
          SiteSetting.refresh_site_setting_group_ids!
          SiteSetting.notify_changed!

          results = result.upcoming_changes
          mock_setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }

          expect(mock_setting[:upcoming_change][:enabled_for]).to eq("groups")
        end

        context "when the staff group has been localized" do
          before do
            SiteSetting.default_locale = "de"
            Group.refresh_automatic_group!(:staff)
          end

          it "sets enabled_for to the localized staff group name when setting value is true and group is staff" do
            SiteSetting.enable_upload_debug_mode = true
            SiteSettingGroup.create!(
              name: "enable_upload_debug_mode",
              group_ids: Group::AUTO_GROUPS[:staff].to_s,
            )
            SiteSetting.refresh_site_setting_group_ids!
            SiteSetting.notify_changed!

            results = result.upcoming_changes
            setting = results.find { |change| change[:setting] == :enable_upload_debug_mode }
            expect(setting[:upcoming_change][:enabled_for]).to eq(
              Group.find(Group::AUTO_GROUPS[:staff]).name,
            )
          end
        end

        context "when filtering by statuses" do
          let(:options) { { filter_statuses: [:beta] } }

          it "only includes upcoming changes with the given statuses" do
            results = result.upcoming_changes
            expect(
              results.find { |change| change[:setting] == :enable_upload_debug_mode },
            ).not_to be_present
            expect(results.find { |change| change[:setting] == :allow_user_locale }).to be_present
          end
        end
      end

      it "updates the user's last_visited_upcoming_changes_at custom field" do
        expect { result }.to change {
          admin.reload.custom_fields["last_visited_upcoming_changes_at"]
        }.to be_present
        expect(
          Time.zone.parse(admin.custom_fields["last_visited_upcoming_changes_at"]),
        ).to be_within(1.minute).of(Time.current)
      end

      context "when guardian is the system user" do
        let(:guardian) { Discourse.system_user.guardian }

        it "does not update the custom field" do
          expect { result }.not_to change {
            Discourse.system_user.reload.custom_fields["last_visited_upcoming_changes_at"]
          }
        end
      end

      context "when guardian is a bot" do
        fab!(:bot)
        let(:guardian) { bot.guardian }

        it "does not update the custom field" do
          expect { result }.not_to change {
            bot.reload.custom_fields["last_visited_upcoming_changes_at"]
          }
        end
      end
    end
  end
end
