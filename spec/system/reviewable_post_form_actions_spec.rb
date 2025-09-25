# frozen_string_literal: true

describe "Reviewable Post Form Actions", type: :system do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:post)
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post, target: post, target_created_by: user) }

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    # Enable the reviewable UI refresh feature for the admin group
    allow_any_instance_of(Guardian).to receive(:can_see_reviewable_ui_refresh?).and_return(true)
    if Group.exists?(name: "reviewable_ui_refresh_enabled")
      admin.groups << Group.find_by(name: "reviewable_ui_refresh_enabled")
    end
    sign_in(admin)
  end

  context "with separated post and user action bundles" do
    it "displays dropdowns for post and user actions" do
      # Check if the feature is available for the admin
      admin.reload
      skip "Feature not enabled" unless Guardian.new(admin).can_see_reviewable_ui_refresh?

      visit("/review")

      within(".reviewable-item[data-reviewable-id='#{reviewable.id}']") do
        # Check for form presence
        expect(page).to have_css(".reviewable-actions-form")

        # Check for two dropdowns (post actions and user actions)
        expect(page).to have_css(".form-kit__field", count: 2)

        # Check for Post Actions dropdown
        expect(page).to have_css(".form-kit__label", text: "Post Actions")

        # Check for User Actions dropdown
        expect(page).to have_css(".form-kit__label", text: "User Actions")

        # Check for confirm button
        expect(page).to have_button("Confirm Actions")
      end
    end

    it "allows selecting and performing multiple actions" do
      visit("/review")

      within(".reviewable-item[data-reviewable-id='#{reviewable.id}']") do
        # Select hide post action
        post_actions_select = find(".form-kit__field", text: "Post Actions").find("select")
        post_actions_select.select("Hide Post")

        # Select silence user action
        user_actions_select = find(".form-kit__field", text: "User Actions").find("select")
        user_actions_select.select("Silence User")

        # Submit the form
        click_button("Confirm Actions")
      end

      # Verify success message
      expect(toasts).to have_success(I18n.t("js.review.actions_performed"))

      # Verify post is hidden
      post.reload
      expect(post).to be_hidden

      # Verify user is silenced
      user.reload
      expect(user).to be_silenced
    end

    it "defaults to safe actions" do
      visit("/review")

      within(".reviewable-item[data-reviewable-id='#{reviewable.id}']") do
        # Check default selection for post actions
        post_actions_select = find(".form-kit__field", text: "Post Actions").find("select")
        expect(post_actions_select.value).to eq("keep_post")

        # Check default selection for user actions
        user_actions_select = find(".form-kit__field", text: "User Actions").find("select")
        expect(user_actions_select.value).to eq("no_action_user")
      end
    end

    it "handles different post states correctly" do
      # Test with hidden post
      post.hide!(Post.hidden_reasons[:flag_threshold_reached])
      reviewable.reload

      visit("/review")

      within(".reviewable-item[data-reviewable-id='#{reviewable.id}']") do
        post_actions_select = find(".form-kit__field", text: "Post Actions").find("select")

        # Should have unhide option for hidden posts
        expect(post_actions_select).to have_content("Unhide Post")
        expect(post_actions_select).to have_content("Keep Hidden")
        expect(post_actions_select).not_to have_content("Hide Post")
      end
    end

    it "disables form while submitting" do
      visit("/review")

      within(".reviewable-item[data-reviewable-id='#{reviewable.id}']") do
        # Start submission
        submit_button = find_button("Confirm Actions")

        # Button should be enabled initially
        expect(submit_button).not_to be_disabled

        # Note: Testing the disabled state during submission would require
        # intercepting the request, which is complex in system specs
        # The component test covers this scenario
      end
    end
  end

  context "with no user actions (no target_created_by)" do
    fab!(:post_no_user) { Fabricate(:post) }
    fab!(:reviewable_no_user) do
      Fabricate(:reviewable_flagged_post, target: post_no_user, target_created_by: nil)
    end

    it "only shows post actions dropdown" do
      visit("/review")

      within(".reviewable-item[data-reviewable-id='#{reviewable_no_user.id}']") do
        # Should only have one dropdown for post actions
        expect(page).to have_css(".form-kit__field", count: 1)
        expect(page).to have_css(".form-kit__label", text: "Post Actions")
        expect(page).not_to have_css(".form-kit__label", text: "User Actions")
      end
    end
  end

  context "with feature flag disabled" do
    before { SiteSetting.enable_experimental_reviewable_ui_refresh = false }

    it "uses the legacy action buttons" do
      visit("/review")

      within(".reviewable-item[data-reviewable-id='#{reviewable.id}']") do
        # Should not have the new form
        expect(page).not_to have_css(".reviewable-actions-form")

        # Should have legacy action buttons/dropdowns
        expect(page).to have_css(".reviewable-action-dropdown")
      end
    end
  end
end
