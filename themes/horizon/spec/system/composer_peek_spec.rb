# frozen_string_literal: true

describe "Composer peek", type: :system do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic_with_op) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    upload_theme
    sign_in(current_user)
  end

  it "does not show composer peek for small windows" do
    topic_page.visit_topic(topic)
    topic_page.click_footer_reply
    expect(composer).to be_opened

    resize_window(width: 600) { expect(page).to have_no_css(".peek-mode-toggle") }
  end

  it "turns on composer peek and remembers this preference on page load" do
    topic_page.visit_topic(topic)
    topic_page.click_footer_reply
    expect(composer).to be_opened

    resize_window(width: 1380) do
      find(".peek-mode-toggle").click
      expect(page).to have_css("body.peek-mode-active")

      topic_page.visit_topic(topic)
      topic_page.click_footer_reply
      expect(composer).to be_opened
      expect(page).to have_css("body.peek-mode-active")

      find(".peek-mode-toggle").click
      expect(page).to have_no_css("body.peek-mode-active")
    end
  end

  it "hides the composer preview when toggling" do
    topic_page.visit_topic(topic)
    topic_page.click_footer_reply
    expect(composer).to be_opened
    expect(composer).to have_composer_preview

    resize_window(width: 1380) do
      find(".peek-mode-toggle").click
      expect(page).to have_css("body.peek-mode-active")
      expect(composer).to have_no_composer_preview
    end
  end
end
