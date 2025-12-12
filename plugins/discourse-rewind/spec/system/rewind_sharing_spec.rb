# frozen_string_literal: true

describe "DiscourseRewind | rewind sharing", type: :system do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true, trust_level: 2) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true, trust_level: 2) }
  fab!(:admin)

  let(:rewind_page) { PageObjects::Pages::Rewind.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:cdp) { PageObjects::CDP.new }

  before { SiteSetting.discourse_rewind_enabled = true }

  describe "sharing functionality" do
    context "when user shares their rewind" do
      before do
        sign_in(current_user)
        freeze_time DateTime.parse("2022-12-22")
      end

      it "shows confirmation dialog and enables sharing" do
        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_share_toggle
        expect(rewind_page.share_toggle).to be_unchecked
        expect(rewind_page).to have_no_copy_link_button
        expect(current_user.user_option.discourse_rewind_share_publicly).to eq(false)

        rewind_page.share_toggle.toggle

        expect(dialog).to be_open
        expect(dialog).to have_content(I18n.t("js.discourse_rewind.share.confirm"))

        dialog.click_yes

        current_user.reload
        expect(current_user.user_option.discourse_rewind_share_publicly).to eq(true)
        expect(rewind_page.share_toggle).to be_checked
        expect(rewind_page).to have_copy_link_button
      end

      it "does not enable sharing if user cancels confirmation" do
        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_share_toggle
        expect(rewind_page.share_toggle).to be_unchecked
        expect(rewind_page).to have_no_copy_link_button
        expect(current_user.user_option.discourse_rewind_share_publicly).to eq(false)

        rewind_page.share_toggle.toggle

        expect(dialog).to be_open

        dialog.click_no

        current_user.reload
        expect(current_user.user_option.discourse_rewind_share_publicly).to eq(false)
        expect(rewind_page.share_toggle).to be_unchecked
        expect(rewind_page).to have_no_copy_link_button
      end

      it "unshares without confirmation when already shared" do
        current_user.user_option.update!(discourse_rewind_share_publicly: true)

        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_share_toggle
        expect(rewind_page.share_toggle).to be_checked
        expect(rewind_page).to have_copy_link_button

        rewind_page.share_toggle.toggle

        current_user.reload
        expect(current_user.user_option.discourse_rewind_share_publicly).to eq(false)
        expect(rewind_page.share_toggle).to be_unchecked
        expect(rewind_page).to have_no_copy_link_button
      end

      context "when copying rewind link" do
        before { cdp.allow_clipboard }

        it "copies rewind link to clipboard when link button is clicked" do
          current_user.user_option.update!(discourse_rewind_share_publicly: true)

          rewind_page.visit_rewind(current_user.username)

          expect(rewind_page).to have_copy_link_button

          rewind_page.click_copy_link_button

          cdp.clipboard_has_text?("/u/#{current_user.username}/activity/rewind", strict: false)
          expect(PageObjects::Components::Toasts.new).to have_success(
            I18n.t("js.post.controls.link_copied"),
          )
        end

        it "does not show copy link button when sharing is disabled" do
          current_user.user_option.update!(discourse_rewind_share_publicly: false)

          rewind_page.visit_rewind(current_user.username)

          expect(rewind_page).to have_no_copy_link_button
        end
      end
    end

    context "when viewing another user's shared rewind" do
      before do
        sign_in(other_user)
        current_user.user_option.update!(discourse_rewind_share_publicly: true)
        freeze_time DateTime.parse("2022-12-22")
      end

      it "displays the rewind with a message indicating viewing other user" do
        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_viewing_other_user_message(current_user.username)
        expect(rewind_page).to have_no_share_toggle
        expect(rewind_page).to have_no_copy_link_button
        expect(rewind_page).to have_no_cannot_view_rewind_error
        expect(rewind_page).to have_rewind_loaded
      end
    end

    context "when viewing another user's unshared rewind" do
      before do
        sign_in(other_user)
        current_user.user_option.update!(discourse_rewind_share_publicly: false)
        freeze_time DateTime.parse("2022-12-22")
      end

      it "shows error message and cannot view the rewind" do
        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_cannot_view_rewind_error
        expect(rewind_page).to have_no_share_toggle
        expect(rewind_page).to have_no_copy_link_button
      end

      it "can view after current_user enables sharing" do
        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_cannot_view_rewind_error

        current_user.user_option.update!(discourse_rewind_share_publicly: true)

        page.refresh

        expect(rewind_page).to have_no_cannot_view_rewind_error
        expect(rewind_page).to have_viewing_other_user_message(current_user.username)
        expect(rewind_page).to have_rewind_loaded
      end

      it "cannot view after current_user disables sharing" do
        current_user.user_option.update!(discourse_rewind_share_publicly: true)

        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_no_cannot_view_rewind_error
        expect(rewind_page).to have_rewind_loaded

        current_user.user_option.update!(discourse_rewind_share_publicly: false)

        page.refresh

        expect(rewind_page).to have_cannot_view_rewind_error
      end
    end

    context "when admin views any user's rewind" do
      before do
        sign_in(admin)
        freeze_time DateTime.parse("2022-12-22")
      end

      it "can view rewind even when sharing is disabled" do
        current_user.user_option.update!(discourse_rewind_share_publicly: false)

        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_viewing_other_user_message(current_user.username)
        expect(rewind_page).to have_no_share_toggle
        expect(rewind_page).to have_no_copy_link_button
        expect(rewind_page).to have_no_cannot_view_rewind_error
        expect(rewind_page).to have_rewind_loaded
      end

      it "can view rewind when sharing is enabled" do
        current_user.user_option.update!(discourse_rewind_share_publicly: true)

        rewind_page.visit_rewind(current_user.username)

        expect(rewind_page).to have_viewing_other_user_message(current_user.username)
        expect(rewind_page).to have_no_share_toggle
        expect(rewind_page).to have_no_copy_link_button
        expect(rewind_page).to have_no_cannot_view_rewind_error
        expect(rewind_page).to have_rewind_loaded
      end
    end

    context "when anonymous user attempts to view rewind" do
      before { freeze_time DateTime.parse("2022-12-22") }

      it "redirects to /latest when user's rewind is shared" do
        current_user.user_option.update!(discourse_rewind_share_publicly: true)

        rewind_page.visit_rewind(current_user.username)

        expect(page).to have_current_path("/latest")
      end

      it "redirects to /latest when user's rewind is not shared" do
        current_user.user_option.update!(discourse_rewind_share_publicly: false)

        rewind_page.visit_rewind(current_user.username)

        expect(page).to have_current_path("/latest")
      end
    end
  end
end
