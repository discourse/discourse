# frozen_string_literal: true

describe "Composer Preview", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in user }

  it "keeps details element open when morphing content" do
    SiteSetting.enable_diffhtml_preview = true

    visit("/new-topic")

    composer.type_content <<~MD
      [details=Velcro]
      What a rip-off!
      [/details]
    MD

    within(composer.preview) do
      find("details").click
      expect(page).to have_css("details[open]")
    end

    composer.move_cursor_after("rip-off!")
    composer.type_content(" :person_facepalming:")

    within(composer.preview) { expect(page).to have_css("details[open] img.emoji") }
  end
end
