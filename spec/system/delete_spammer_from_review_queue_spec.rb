# frozen_string_literal: true

describe "Deleting a spammer from the review queue" do
  fab!(:admin)
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:spammer) { Fabricate(:user, refresh_auto_groups: true) }

  let(:review_page) { PageObjects::Pages::Review.new }

  before { sign_in(admin) }

  it "clears all of the spammer's pending flags when deleting and blocking them from one flag" do
    flagged_post_reviewable =
      PostActionCreator.spam(flagger, Fabricate(:post, user: spammer)).reviewable
    hidden_post = Fabricate(:post, user: spammer)
    hidden_post_reviewable = PostActionCreator.spam(flagger, hidden_post).reviewable
    hidden_post.hide!(PostActionType.types[:spam])

    visit("/review")

    expect(review_page).to have_reviewable_items(count: 2)

    review_page.select_bundled_action(
      flagged_post_reviewable,
      "post-delete_user_block",
      bundle_index: 1,
    )

    expect(review_page).to have_reviewable_with_approved_status(flagged_post_reviewable)

    page.refresh

    expect(review_page).to have_no_reviewable_items
  end

  it "lets the moderator delete and block a spammer whose account was already deleted" do
    flagged_post = Fabricate(:post, user: spammer)
    flagged_post_reviewable = PostActionCreator.spam(flagger, flagged_post).reviewable

    visit("/review")

    expect(review_page).to have_reviewable_items(count: 1)

    # The spammer is deleted elsewhere (e.g. by another moderator) while this
    # page still shows the flag with its delete user actions.
    flagged_post.trash!(Discourse.system_user)
    UserDestroyer.new(Discourse.system_user).destroy(spammer, context: "spec")

    review_page.select_bundled_action(
      flagged_post_reviewable,
      "post-delete_user_block",
      bundle_index: 1,
    )

    expect(review_page).to have_reviewable_with_approved_status(flagged_post_reviewable)
    expect(review_page).to have_no_error_dialog_visible
  end
end
