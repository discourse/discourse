# frozen_string_literal: true

describe "Composer - Event preview focus" do
  fab!(:admin)

  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    sign_in(admin)
  end

  it "keeps the topic title focused on the first click after editing the event preview" do
    visit("/new-topic")

    find(".toolbar-menu__options-trigger").click
    click_button(I18n.t("js.discourse_post_event.builder_modal.attach"))

    expect(page).to have_css(".d-editor-preview .composer-event-editor")

    find(".composer-event-editor .composer-event__name-input").fill_in(with: "My offsite")

    find("#reply-title").click

    title_focused =
      page.evaluate_script("document.activeElement === document.querySelector('#reply-title')")
    expect(title_focused).to eq(true)

    # the edit is still committed even though focus never moved to the editor
    expect(composer).to have_value(/name="My offsite"/)
  end
end
