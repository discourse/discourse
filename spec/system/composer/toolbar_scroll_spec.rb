# frozen_string_literal: true

describe "Composer | Toolbar scroll" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }

  def open_composer
    page.visit "/new-topic"
    expect(composer).to be_opened
  end

  def right_scroll_btn
    ".d-editor-button-bar__scroll-btn.--right"
  end

  def left_scroll_btn
    ".d-editor-button-bar__scroll-btn.--left"
  end

  it "shows scroll buttons when the toolbar overflows" do
    sign_in(current_user)

    resize_window(width: 650) do
      open_composer

      expect(page).to have_css(right_scroll_btn)
      expect(page).to have_no_css(left_scroll_btn)

      find(right_scroll_btn).click

      expect(page).to have_css(left_scroll_btn)

      find(left_scroll_btn).click

      expect(page).to have_no_css(left_scroll_btn)
    end
  end

  context "when RTL locale" do
    before { SiteSetting.default_locale = "he" }

    it "scrolls the toolbar in the correct direction" do
      sign_in(current_user)

      resize_window(width: 650) do
        open_composer

        expect(page).to have_css(right_scroll_btn)
        expect(page).to have_no_css(left_scroll_btn)

        find(right_scroll_btn).click

        expect(page).to have_css(left_scroll_btn)

        find(left_scroll_btn).click

        expect(page).to have_no_css(left_scroll_btn)
      end
    end
  end
end
