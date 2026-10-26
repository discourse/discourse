# frozen_string_literal: true

RSpec.describe Admin::UsersController do
  fab!(:admin)
  fab!(:user)
  fab!(:group1) { Fabricate(:group, name: "test_group_1") }
  fab!(:group2) { Fabricate(:group, name: "test_group_2") }

  describe "#show" do
    before do
      sign_in(admin)
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "feature,all_members",
            status: :beta,
            impact_type: "feature",
            impact_role: "all_members",
          },
        },
      )
    end

    it "includes only the targeted groups that the user belongs to" do
      SiteSetting.enable_upload_debug_mode = true
      Fabricate(
        :site_setting_group,
        name: "enable_upload_debug_mode",
        group_ids: "#{group1.id}|#{group2.id}",
      )
      group1.add(user)

      get "/admin/users/#{user.id}.json"

      expect(response.status).to eq(200)
      change =
        response
          .parsed_body
          .fetch("upcoming_changes_stats")
          .find { |entry| entry["name"] == "enable_upload_debug_mode" }
      expect(change).to include(
        "name" => "enable_upload_debug_mode",
        "enabled" => true,
        "reason" => "in_specific_groups",
        "specific_groups" => [group1.name],
      )
    end

    it "includes a beta change and omits a conceptual change" do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "feature,all_members",
            status: :beta,
            impact_type: "feature",
            impact_role: "all_members",
          },
          about_page_extra_groups_show_description: {
            impact: "feature,all_members",
            status: :conceptual,
            impact_type: "feature",
            impact_role: "all_members",
          },
        },
      )

      get "/admin/users/#{user.id}.json"

      expect(response.status).to eq(200)
      names =
        response.parsed_body.fetch("upcoming_changes_stats").map { |entry| entry.fetch("name") }
      expect(names).to include("enable_upload_debug_mode")
      expect(names).not_to include("about_page_extra_groups_show_description")
    end
  end
end
