# frozen_string_literal: true

describe "PM user removal", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:other_user) { Fabricate(:user) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(current_user) }

  %w[enabled disabled].each do |setting|
    context "when the setting is #{setting}" do
      before { SiteSetting.glimmer_post_stream_mode = setting }

      it "removes a user from the PM list" do
        pm =
          create_post(
            user: current_user,
            target_usernames: [other_user.username],
            archetype: Archetype.private_message,
          ).topic

        topic_page.visit_topic(pm)

        find(".add-remove-participant-btn").click
        find(".user[data-id='#{other_user.id}'] .remove-invited").click
        dialog.click_danger

        expect(page).to have_selector(
          ".small-action-contents",
          text: "Removed @#{other_user.username} just now",
        )
      end

      it "removes a group from the PM list" do
        group =
          Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap do |g|
            g.add(other_user)
          end

        pm =
          create_post(
            user: current_user,
            target_group_names: [group.name],
            archetype: Archetype.private_message,
          ).topic

        topic_page.visit_topic(pm)

        find(".add-remove-participant-btn").click
        find(".group[data-id='#{group.id}'] .remove-invited").click
        dialog.click_danger

        expect(page).to have_selector(
          ".small-action-contents",
          text: "Removed @#{group.name} just now",
        )
      end
    end
  end
end
