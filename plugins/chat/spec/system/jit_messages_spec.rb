# frozen_string_literal: true

RSpec.describe "JIT messages", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    channel_1.add(current_user)
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when mentioning a user" do
    context "when user is not on the channel" do
      it "displays a mention warning" do
        Jobs.run_immediately!

        chat.visit_channel(channel_1)
        channel.send_message("hi @#{other_user.username}")

      expect(page).to have_content(
        I18n.t("js.chat.mention_warning.without_membership", username: other_user.username),
        wait: 5,
      )
    end
  end

    context "when user can’t access the channel" do
      fab!(:group_1) { Fabricate(:group) }
      fab!(:private_channel_1) { Fabricate(:private_category_channel, group: group_1) }

      before do
        group_1.add(current_user)
        private_channel_1.add(current_user)
      end

      it "displays a mention warning" do
        Jobs.run_immediately!

        chat.visit_channel(private_channel_1)
        channel.send_message("hi @#{other_user.username}")

        expect(page).to have_content(
          I18n.t("js.chat.mention_warning.cannot_see.one", username: other_user.username),
          wait: 5,
        )
      end
    end

    context "when user can’t access a non read_restrictd channel" do
      let!(:everyone) { Group.find(Group::AUTO_GROUPS[:everyone]) }
      fab!(:category) { Fabricate(:category) }
      fab!(:readonly_channel) { Fabricate(:category_channel, chatable: category) }

      before do
        Fabricate(
          :category_group,
          category: category,
          group: everyone,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
        everyone.add(other_user)
        readonly_channel.add(current_user)
      end

      it "displays a mention warning" do
        Jobs.run_immediately!

        chat.visit_channel(readonly_channel)
        channel.send_message("hi @#{other_user.username}")

        expect(page).to have_content(
          I18n.t("js.chat.mention_warning.cannot_see.one", username: other_user.username),
          wait: 5,
        )
      end
    end
  end

  context "when category channel permission is readonly for everyone" do
    fab!(:group_1) { Fabricate(:group) }
    fab!(:private_channel_1) { Fabricate(:private_category_channel, group: group_1) }

    before do
      group_1.add(current_user)
      private_channel_1.add(current_user)
    end

    it "displays a mention warning" do
      Jobs.run_immediately!

      chat.visit_channel(private_channel_1)
      channel.send_message("hi @#{other_user.username}")

      expect(page).to have_content(
        I18n.t("js.chat.mention_warning.cannot_see", username: other_user.username),
        wait: 5,
      )
    end
  end

  context "when mention a group" do
    context "when group can't be mentioned" do
      fab!(:group_1) { Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:nobody]) }

      it "displays a mention warning" do
        Jobs.run_immediately!

        chat.visit_channel(channel_1)
        channel.send_message("hi @#{group_1.name}")

        expect(page).to have_content(
          I18n.t("js.chat.mention_warning.group_mentions_disabled", group_name: group_1.name),
          wait: 5,
        )
      end
    end
  end
end
