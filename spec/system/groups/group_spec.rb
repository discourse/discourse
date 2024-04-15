# frozen_string_literal: true

describe "Group", type: :system do
  let(:group_page) { PageObjects::Pages::Group.new }
  fab!(:admin)
  fab!(:group)

  before { sign_in(admin) }

  describe "delete a group" do
    it "redirects to groups index page" do
      group_page.visit(group)

      group_page.delete_group

      expect(page).to have_current_path("/g")
    end
  end
end
