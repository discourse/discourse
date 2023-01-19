# frozen_string_literal: true

RSpec.describe "Create channel", type: :system, js: true do
  fab!(:current_admin_user) { Fabricate(:admin) }
  fab!(:category_1) { Fabricate(:category) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    sign_in(current_admin_user)
  end

  context "when can create channel" do
    context "when selecting a category" do
      it "shows access hint" do
        visit("/chat")
        find(".new-channel-btn").click
        find(".category-chooser").click
        find(".category-row[data-value=\"#{category_1.id}\"]").click

        expect(find(".create-channel-hint")).to have_content(Group[:everyone].name)
      end

      it "does not override channel name if that was already specified" do
        visit("/chat")
        find(".new-channel-btn").click
        fill_in("channel-name", with: "My Cool Channel")
        find(".category-chooser").click
        find(".category-row[data-value=\"#{category_1.id}\"]").click

        expect(page).to have_field("channel-name", with: "My Cool Channel")
      end

      context "when category is private" do
        fab!(:group_1) { Fabricate(:group) }
        fab!(:private_category_1) { Fabricate(:private_category, group: group_1) }

        it "shows access hint when selecting the category" do
          visit("/chat")
          find(".new-channel-btn").click
          find(".category-chooser").click
          find(".category-row[data-value=\"#{private_category_1.id}\"]").click

          expect(find(".create-channel-hint")).to have_content(group_1.name)
        end

        context "when category is a child" do
          fab!(:group_2) { Fabricate(:group) }
          fab!(:child_category) do
            Fabricate(:private_category, parent_category_id: private_category_1.id, group: group_2)
          end

          it "shows access hint when selecting the category" do
            visit("/chat")
            find(".new-channel-btn").click
            find(".category-chooser").click
            find(".category-row[data-value=\"#{child_category.id}\"]").click

            expect(find(".create-channel-hint")).to have_content(group_2.name)
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
        visit("/chat")
        find(".new-channel-btn").click
        find(".category-chooser").click
        find(".category-row[data-value=\"#{private_category_1.id}\"]").click

        expect(find(".create-channel-hint")["innerHTML"].strip).to include(
          "&lt;script&gt;e&lt;/script&gt;",
        )
      end
    end

    context "when saving" do
      context "when error" do
        it "displays the error" do
          existing_channel = Fabricate(:chat_channel)
          visit("/chat")
          find(".new-channel-btn").click
          find(".category-chooser").click
          find(".category-row[data-value=\"#{existing_channel.chatable_id}\"]").click
          fill_in("channel-name", with: existing_channel.name)
          find(".create-channel-modal .create").click

          expect(page).to have_content(I18n.t("chat.errors.channel_exists_for_category"))
        end
      end

      context "when successful" do
        it "redirects to created channel" do
          visit("/chat")
          find(".new-channel-btn").click
          name = "Cats"
          find(".category-chooser").click
          find(".category-row[data-value=\"#{category_1.id}\"]").click
          expect(page).to have_field("channel-name", with: category_1.name)
          fill_in("channel-name", with: name)
          fill_in("channel-description", with: "All kind of cute cats")
          find(".create-channel-modal .create").click

          expect(page).to have_content(name)
          created_channel = ChatChannel.find_by(chatable_id: category_1.id)
          expect(page).to have_current_path(
            chat.channel_path(created_channel.id, created_channel.slug),
          )
        end
      end
    end
  end
end
