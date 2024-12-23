# frozen_string_literal: true

RSpec.describe "Create channel", type: :system do
  fab!(:category_1) { Fabricate(:category) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_modal) { PageObjects::Modals::ChatChannelCreate.new }

  before { chat_system_bootstrap }

  context "when user cannot create channel" do
    fab!(:current_user) { Fabricate(:user) }

    before { sign_in(current_user) }

    it "does not show the create channel button" do
      chat_page.visit_browse
      expect(chat_page).to have_no_new_channel_button
    end
  end

  context "when can create channel" do
    fab!(:current_admin_user) { Fabricate(:admin) }
    before { sign_in(current_admin_user) }

    context "when selecting a category" do
      it "shows access hint" do
        chat_page.visit_browse
        chat_page.new_channel_button.click
        channel_modal.select_category(category_1)

        expect(channel_modal).to have_create_hint(Group[:everyone].name)
      end

      it "shows threading toggle" do
        chat_page.visit_browse
        chat_page.new_channel_button.click
        channel_modal.select_category(category_1)

        expect(channel_modal).to have_threading_toggle
      end

      it "does not override channel name if that was already specified" do
        chat_page.visit_browse
        chat_page.new_channel_button.click
        channel_modal.fill_name("My Cool Channel")
        channel_modal.select_category(category_1)

        expect(channel_modal).to have_name_prefilled("My Cool Channel")
      end

      context "when category is private" do
        fab!(:group_1) { Fabricate(:group) }
        fab!(:private_category_1) { Fabricate(:private_category, group: group_1) }

        it "shows access hint when selecting the category" do
          chat_page.visit_browse
          chat_page.new_channel_button.click
          channel_modal.select_category(private_category_1)

          expect(channel_modal).to have_create_hint(group_1.name)
        end

        context "when category is a child" do
          fab!(:group_2) { Fabricate(:group) }
          fab!(:child_category) do
            Fabricate(:private_category, parent_category_id: private_category_1.id, group: group_2)
          end

          it "shows access hint when selecting the category" do
            chat_page.visit_browse
            chat_page.new_channel_button.click
            channel_modal.select_category(child_category)

            expect(channel_modal).to have_create_hint(group_2.name)
          end
        end
      end
    end

    context "when category has a malicious group name" do
      fab!(:group_1) do
        group = Group.new(name: "<script>e</script>")
        group.save(validate: false)
        group
      end
      fab!(:private_category_1) { Fabricate(:private_category, group: group_1) }

      it "escapes the group name" do
        chat_page.visit_browse
        chat_page.new_channel_button.click
        channel_modal.select_category(private_category_1)
        expect(page).to have_no_css(".loading-permissions")

        expect(channel_modal.create_channel_hint["innerHTML"].strip).to include(
          "&lt;script&gt;e&lt;/script&gt;",
        )
      end
    end

    it "autogenerates slug from name and changes slug placeholder" do
      chat_page.visit_browse
      chat_page.new_channel_button.click
      name = "Cats & Dogs"
      channel_modal.select_category(category_1)
      channel_modal.fill_name(name)
      channel_modal.fill_description("All kind of cute cats")

      wait_for_attribute(channel_modal.slug_input, :placeholder, "cats-dogs")

      channel_modal.click_primary_button

      expect(page).to have_content(name)
      created_channel = Chat::Channel.find_by(chatable_id: category_1.id)
      expect(created_channel.slug).to eq("cats-dogs")
      expect(page).to have_current_path(chat.channel_path(created_channel.slug, created_channel.id))
    end

    it "allows the user to set a slug independently of name" do
      chat_page.visit_browse
      chat_page.new_channel_button.click
      name = "Cats & Dogs"
      channel_modal.select_category(category_1)
      channel_modal.fill_name(name)
      channel_modal.fill_description("All kind of cute cats")
      channel_modal.fill_slug("pets-everywhere")
      channel_modal.click_primary_button

      expect(page).to have_content(name)
      created_channel = Chat::Channel.find_by(chatable_id: category_1.id)
      expect(created_channel.slug).to eq("pets-everywhere")
      expect(page).to have_current_path(chat.channel_path(created_channel.slug, created_channel.id))
    end

    context "when saving" do
      context "when user has chosen to automatically add users" do
        let(:dialog) { PageObjects::Components::Dialog.new }
        let(:name) { "Cats & Dogs" }

        before do
          chat_page.visit_browse
          chat_page.new_channel_button.click
          channel_modal.fill_name(name)
        end

        context "for a public category" do
          before do
            channel_modal.select_category(category_1)
            find(".-auto-join .chat-modal-create-channel__label").click
            channel_modal.click_primary_button
          end

          it "displays the correct warning" do
            expect(dialog).to have_content(
              I18n.t(
                "js.chat.create_channel.auto_join_users.public_category_warning",
                category: category_1.name,
              ),
            )
          end

          it "allows the user to proceed with channel creation" do
            dialog.click_yes
            expect(page).to have_content(name)
            created_channel = Chat::Channel.find_by(chatable_id: category_1.id)
            expect(page).to have_current_path(
              chat.channel_path(created_channel.slug, created_channel.id),
            )
          end

          it "does nothing if no is clicked" do
            dialog.click_no
            expect(page).to have_css(".chat-modal-create-channel")
            expect(Chat::Channel.exists?(chatable_id: category_1.id)).to eq(false)
          end
        end

        context "for a private category" do
          fab!(:group_1) { Fabricate(:group) }
          fab!(:user_1) { Fabricate(:user) }
          fab!(:private_category) { Fabricate(:private_category, group: group_1) }

          before do
            group_1.add(user_1)
            channel_modal.select_category(private_category)
            find(".-auto-join .chat-modal-create-channel__label").click
            channel_modal.click_primary_button
          end

          context "when only 1 group can access the category" do
            it "displays the correct warning" do
              expect(dialog).to have_content(
                I18n.t(
                  "js.chat.create_channel.auto_join_users.warning_1_group",
                  count: 1,
                  group: "@#{group_1.name}",
                ),
              )
            end
          end

          context "when 2 groups can access the category" do
            fab!(:group_2) { Fabricate(:group) }
            fab!(:category_group_2) do
              CategoryGroup.create(group: group_2, category: private_category)
            end

            it "displays the correct warning" do
              expect(dialog).to have_content(
                I18n.t(
                  "js.chat.create_channel.auto_join_users.warning_2_groups",
                  count: 1,
                  group1: "@#{group_1.name}",
                  group2: "@#{group_2.name}",
                ),
              )
            end
          end

          context "when > 2 groups can access the category" do
            fab!(:group_2) { Fabricate(:group) }
            fab!(:category_group_2) do
              CategoryGroup.create(group: group_2, category: private_category)
            end

            fab!(:group_3) { Fabricate(:group) }
            fab!(:category_group_3) do
              CategoryGroup.create(group: group_3, category: private_category)
            end

            it "displays the correct warning" do
              # NOTE: This has to be hardcoded because the I18n module in ruby
              # does not support messageFormat.
              expect(dialog).to have_content(
                "Automatically add 1 user from @#{group_1.name} and 2 other groups?",
              )
            end
          end
        end
      end

      context "when error" do
        it "displays the error" do
          existing_channel = Fabricate(:chat_channel)
          chat_page.visit_browse
          chat_page.new_channel_button.click
          channel_modal.select_category(existing_channel.chatable)
          channel_modal.fill_name(existing_channel.name)
          channel_modal.click_primary_button

          expect(page).to have_content(I18n.t("chat.errors.channel_exists_for_category"))
        end
      end

      context "when slug is already being used" do
        it "displays the error" do
          Fabricate(:chat_channel, slug: "pets-everywhere")
          chat_page.visit_browse
          chat_page.new_channel_button.click
          channel_modal.select_category(category_1)
          channel_modal.fill_name("Testing")
          channel_modal.fill_slug("pets-everywhere")
          channel_modal.click_primary_button

          expect(page).to have_content(
            "Slug " + I18n.t("chat.category_channel.errors.is_already_in_use"),
          )
        end
      end

      context "when successful" do
        it "redirects to created channel" do
          chat_page.visit_browse
          chat_page.new_channel_button.click
          channel_modal.select_category(category_1)

          expect(channel_modal).to have_name_prefilled(category_1.name)

          channel_modal.fill_description("All kind of cute cats")
          channel_modal.click_primary_button

          expect(channel_modal).to be_closed

          created_channel = Chat::Channel.find_by(chatable_id: category_1.id)
          expect(page).to have_current_path(
            chat.channel_path(created_channel.slug, created_channel.id),
          )
        end
      end
    end
  end
end
