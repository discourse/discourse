# frozen_string_literal: true

describe "DiscourseRewind | rewind avatar decoration and callout", type: :system do
  fab!(:current_user, :user)
  let(:rewind_page) { PageObjects::Pages::Rewind.new }

  before do
    SiteSetting.discourse_rewind_enabled = true
    sign_in(current_user)
  end

  def visit_and_dismiss_rewind
    visit("/")

    expect(rewind_page).to have_rewind_notification_active
    rewind_page.open_user_menu
    rewind_page.click_callout
    expect(rewind_page).to have_rewind_header
    expect(rewind_page).to be_on_rewind_page(current_user.username)

    visit("/")
  end

  context "when in december" do
    before { freeze_time DateTime.parse("2022-12-05") }

    it "shows avatar decoration and callout" do
      visit("/")

      expect(rewind_page).to have_rewind_notification_active
      rewind_page.open_user_menu
      expect(rewind_page).to have_callout
    end

    describe "header icon" do
      # TODO (martin) Fix this spec, for some reason it makes have_rewind_header fail
      xit "shows the correct message", time: Time.utc(2022, 12, 05) do
        visit_and_dismiss_rewind

        rewind_page.click_rewind_header_icon

        expect(page).to have_content(
          I18n.t(
            "js.discourse_rewind.header_tooltip.description",
            rewindYear: DiscourseRewind.year_date_range.first.year,
            nextYear: DiscourseRewind.year_date_range.first.year + 1,
          ),
        )
      end

      it "can navigate to the rewind page from the tooltip" do
        visit_and_dismiss_rewind

        rewind_page.click_rewind_header_icon
        rewind_page.click_header_tooltip_cta

        expect(rewind_page).to be_on_rewind_page(current_user.username)
      end

      it "can navigate to the user rewind preferences from the tooltip" do
        visit_and_dismiss_rewind

        rewind_page.click_rewind_header_icon
        rewind_page.click_header_tooltip_preferences_link

        expect(page).to have_current_path("/u/#{current_user.username}/preferences/rewind")
        expect(page).to have_content(I18n.t("js.discourse_rewind.preferences.disable_rewind"))
      end
    end

    context "when the user dismisses rewind by clicking the callout" do
      it "no longer shows the callout" do
        visit_and_dismiss_rewind
        expect(rewind_page).to have_no_rewind_notification_active
      end

      it "shows the header icon" do
        visit_and_dismiss_rewind
        expect(rewind_page).to have_rewind_header_icon
      end
    end

    context "when user has disabled rewind" do
      before { current_user.user_option.update!(discourse_rewind_disabled: true) }

      it "does not show the callout" do
        visit("/")

        expect(rewind_page).to have_no_rewind_notification_active
      end

      context "when user has dismissed rewind previously" do
        it "does not show the header icon" do
          set_local_storage("discourse_rewind_2022_dismissed", "true")
          visit("/")

          expect(rewind_page).to have_no_rewind_header_icon
        end
      end
    end
  end

  context "when in november" do
    before { freeze_time DateTime.parse("2022-11-24") }

    it "doesn't show the avatar decoration and callout" do
      visit("/")

      expect(rewind_page).to have_no_rewind_notification_active
    end

    it "doesn't show the header icon" do
      visit("/")

      expect(rewind_page).to have_no_rewind_header_icon
    end
  end
end
