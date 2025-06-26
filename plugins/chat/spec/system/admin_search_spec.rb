# frozen_string_literal: true

describe "Admin Search Plugin Pages", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  let(:search_modal) { PageObjects::Modals::AdminSearch.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(current_user) }

  it "can find admin plugin pages in admin search" do
    visit "/admin"
    sidebar.click_search_input
    search_modal.search("incoming webhooks")

    expect(search_modal.find_result("page", 0)).to have_content(
      I18n.t("js.chat.incoming_webhooks.title"),
    )
    expect(search_modal.find_result("page", 0)).to have_content(
      I18n.t("js.chat.incoming_webhooks.header_description"),
    )
  end
end
