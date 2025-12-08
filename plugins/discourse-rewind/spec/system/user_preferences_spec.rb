# frozen_string_literal: true

describe "DiscourseRewind | user preferences", type: :system do
  fab!(:current_user, :user)

  before do
    SiteSetting.discourse_rewind_enabled = true
    sign_in(current_user)
  end

  context "when in december" do
    before { freeze_time DateTime.parse("2022-12-05") }

    context "when discourse_rewind_disabled is false" do
      it "shows the rewind tab" do
        visit("/my/activity")

        expect(page).to have_selector(".user-nav__activity-rewind")
      end
    end

    context "when discourse_rewind_disabled is true" do
      before { current_user.user_option.update!(discourse_rewind_disabled: true) }

      it "does not show the rewind tab" do
        visit("/my/activity")

        expect(page).to have_no_selector(".user-nav__activity-rewind")
      end
    end
  end
end
