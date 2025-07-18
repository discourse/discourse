# frozen_string_literal: true

describe "Post event", type: :system do
  fab!(:admin)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:post_event_page) { PageObjects::Pages::DiscourseCalendar::PostEvent.new }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:post_event_form_page) { PageObjects::Pages::DiscourseCalendar::PostEventForm.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    sign_in(admin)
  end

  it "correctly builds the description" do
    visit("/")

    time = Time.now.strftime("%Y-%m-%d %H:%M")

    TEXT = <<~EVENT
      [event start="#{time}" status="public" timezone="Europe/Paris" allowedGroups="trust_level_0"]
      foo
      bar
      [/event]
    EVENT

    category_page.new_topic_button.click
    find(".toolbar-menu__options-trigger").click
    click_button(I18n.t("js.discourse_post_event.builder_modal.attach"))
    post_event_form_page.fill_description("foo\nbar").submit

    expect(composer).to have_value(TEXT.strip)
  end
end
