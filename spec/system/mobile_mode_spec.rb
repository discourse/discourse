# frozen_string_literal: true

RSpec.describe "Viewport-based mobile mode" do
  it "updates classes at runtime" do
    visit "/"

    expect(page).to have_css("html.desktop-view")
    expect(page).not_to have_css("html.mobile-view")

    resize_window(width: 400) do
      expect(page).to have_css("html.mobile-view")
      expect(page).not_to have_css("html.desktop-view")
    end
  end

  context "when resizing viewport while on a topic page" do
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic:) }

    it "handles navigation after resize from mobile to desktop" do
      resize_window(width: 400) do
        visit "/t/#{topic.slug}/#{topic.id}"
        expect(page).to have_css("html.mobile-view")
      end

      click_logo
      expect(page).to have_css(".topic-list")
    end

    it "handles navigation after resize from desktop to mobile" do
      visit "/t/#{topic.slug}/#{topic.id}"
      expect(page).to have_css("html.desktop-view")

      resize_window(width: 400) do
        expect(page).to have_css("html.mobile-view")
        click_logo
        expect(page).to have_css(".topic-list")
      end
    end
  end
end
