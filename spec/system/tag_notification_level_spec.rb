# frozen_string_literal: true

describe "Tag notification level", type: :system, js: true do
  let(:tags_page) { PageObjects::Pages::Tag.new }
  let(:select_kit) do
    PageObjects::Components::SelectKit.new(page.find(".tag-notifications-button"))
  end

  fab!(:tag_1) { Fabricate(:tag) }
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  describe "when changing a tag's notification level" do
    it "should change instantly" do
      tags_page.visit_tag(tag_1)
      expect(select_kit).to have_selected_name("regular")

      select_kit.select_row_by_name("watching")

      expect(select_kit).to have_selected_name("watching")
    end
  end
end
