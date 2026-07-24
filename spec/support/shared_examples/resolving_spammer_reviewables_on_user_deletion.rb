# frozen_string_literal: true

RSpec.shared_examples "resolving a spammer's reviewables on user deletion" do
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:spammer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:watching_admin, :admin)

  let(:review_page) { PageObjects::Pages::Review.new }

  before { Jobs.run_immediately! }

  it "resolves every reviewable tied to the spammer in the acting and watching queues" do
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

    action, resolved_status =
      case acted_reviewable.type
      when "ReviewableFlaggedPost", "ReviewableAiPost"
        ["post-delete_user_block", :approved]
      when "ReviewableQueuedPost"
        ["delete_user", :rejected]
      end

    all = [acted_reviewable, flag, queued_post, user_review, review_every_post]

    using_session(:other_tab) do
      sign_in(watching_admin)
      visit("/review")

      expect(review_page).to have_reviewables(all)
    end

    visit("/review")

    expect(review_page).to have_reviewables(all)

    review_page.delete_user_from_reviewable(acted_reviewable, action)

    expect(review_page).to have_reviewable_with_status(acted_reviewable, resolved_status)
    expect(review_page).to have_reviewable_with_approved_status(flag)
    expect(review_page).to have_reviewable_with_rejected_status(queued_post)
    expect(review_page).to have_reviewable_with_rejected_status(user_review)
    expect(review_page).to have_reviewable_with_rejected_status(review_every_post)

    using_session(:other_tab) do
      expect(review_page).to have_reviewable_with_status(acted_reviewable, resolved_status)
      expect(review_page).to have_reviewable_with_approved_status(flag)
      expect(review_page).to have_reviewable_with_rejected_status(queued_post)
      expect(review_page).to have_reviewable_with_rejected_status(user_review)
      expect(review_page).to have_reviewable_with_rejected_status(review_every_post)
    end
  end
end
