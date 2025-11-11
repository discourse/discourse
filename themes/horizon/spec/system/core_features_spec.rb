# frozen_string_literal: true

RSpec.describe "Core features", type: :system do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }

  before { upload_theme_or_component }

  it_behaves_like "having working core features",
                  skip_examples: %i[search:quick_search topics:create]

  it "creates a new topic" do
    sign_in(current_user)
    visit("/new-topic")
    composer.fill_title("This is a new topic")
    composer.fill_content("This is a long enough sentence.")
    expect(page).to have_css(".d-editor-preview p", visible: true)
    within(".save-or-cancel") { click_button("Create Topic") }
    expect(page).to have_content("This is a new topic")
    expect(page).to have_content("This is a long enough sentence.")
  end
end
