# frozen_string_literal: true

RSpec.describe "Create channel", type: :system, js: true do
  fab!(:category_1) { Fabricate(:category) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_modal) { PageObjects::Modals::ChatChannelCreate.new }

  before { chat_system_bootstrap }

  context "when user cannot create channel" do
    fab!(:current_user) { Fabricate(:user) }
    before { sign_in(current_user) }

    it "does not show the create channel button" do
      chat_page.visit_browse
      expect(chat_page).not_to have_new_channel_button
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

    context "when category has a malicous group name" do
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
      created_channel = ChatChannel.find_by(chatable_id: category_1.id)
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
      created_channel = ChatChannel.find_by(chatable_id: category_1.id)
      expect(created_channel.slug).to eq("pets-everywhere")
      expect(page).to have_current_path(chat.channel_path(created_channel.slug, created_channel.id))
    end

    context "when saving" do
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

          expect(page).to have_content(category_1.name)
          created_channel = ChatChannel.find_by(chatable_id: category_1.id)
          expect(page).to have_current_path(
            chat.channel_path(created_channel.slug, created_channel.id),
          )
        end
      end
    end
  end
end
