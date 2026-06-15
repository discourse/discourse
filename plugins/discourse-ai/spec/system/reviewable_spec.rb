# frozen_string_literal: true

describe "Resolving reviewables when deleting a spammer from an AI post reviewable" do
  fab!(:admin)
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:spammer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:watching_admin, :admin)

  let(:review_page) { PageObjects::Pages::Review.new }

  before do
    enable_current_plugin
    sign_in(admin)
    Jobs.run_immediately!
  end

  it "resolves every reviewable tied to the spammer in the acting and watching queues" do
    acted_ai_post =
      ReviewableAiPost.needs_review!(
        target: Fabricate(:post, user: spammer),
        created_by: Discourse.system_user,
      )
    flag = PostActionCreator.spam(flagger, Fabricate(:post, user: spammer)).reviewable
    flag.target.update!(
      hidden: true,
      hidden_at: Time.zone.now,
      hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached],
    )
    queued_post =
      Fabricate(
        :reviewable_queued_post,
        created_by: Discourse.system_user,
        target_created_by: spammer,
      )
    user_review = ReviewableUser.create_for(spammer)
    review_every_post = ReviewablePost.queue_for_review(Fabricate(:post, user: spammer))

    all = [acted_ai_post, flag, queued_post, user_review, review_every_post]

    using_session(:other_tab) do
      sign_in(watching_admin)
      visit("/review")

      expect(review_page).to have_reviewables(all)
    end

    visit("/review")

    expect(review_page).to have_reviewables(all)

    review_page.select_bundled_action(acted_ai_post, "post-delete_user_block", bundle_index: 1)

    expect(review_page).to have_reviewable_with_approved_status(acted_ai_post)
    expect(review_page).to have_reviewable_with_approved_status(flag)
    expect(review_page).to have_reviewable_with_rejected_status(queued_post)
    expect(review_page).to have_reviewable_with_rejected_status(user_review)
    expect(review_page).to have_reviewable_with_rejected_status(review_every_post)

    using_session(:other_tab) do
      expect(review_page).to have_reviewable_with_approved_status(acted_ai_post)
      expect(review_page).to have_reviewable_with_approved_status(flag)
      expect(review_page).to have_reviewable_with_rejected_status(queued_post)
      expect(review_page).to have_reviewable_with_rejected_status(user_review)
      expect(review_page).to have_reviewable_with_rejected_status(review_every_post)
    end
  end
end
