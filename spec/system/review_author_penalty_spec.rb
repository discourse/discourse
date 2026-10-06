# frozen_string_literal: true

describe "Review queue | author penalty" do
  fab!(:admin)
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:author) { Fabricate(:user, username: "spammer99", refresh_auto_groups: true) }
  fab!(:flagged_post) { Fabricate(:post, user: author) }

  let!(:reviewable) { PostActionCreator.spam(flagger, flagged_post).reviewable }
  let(:review_page) { PageObjects::Pages::Review.new }

  before { sign_in(admin) }

  def silence_author!(post_id: flagged_post.id)
    UserSilencer.silence(
      author,
      Discourse.system_user,
      post_id: post_id,
      reason: "Silenced automatically",
    )
  end

  it "says nothing when the author has no penalty" do
    review_page.visit_reviewable(reviewable)

    expect(review_page).to have_reviewable_action_dropdown
    expect(page).to have_no_css(
      ".review-item__meta-flagged-user .d-icon-microphone-slash",
      visible: :all,
    )
    expect(page).to have_no_css(".reviewable-action.post-unsilence-user")
  end

  context "when automated tooling silenced the author for this post" do
    before do
      flagged_post.update!(hidden: true, hidden_at: Time.zone.now)
      silence_author!
    end

    it "marks the flagged user as silenced" do
      review_page.visit_reviewable(reviewable)

      expect(page).to have_css(
        ".review-item__meta-flagged-user .d-icon-microphone-slash",
        visible: :all,
      )
      expect(page).to have_css(
        ".review-item__meta-flagged-user .svg-icon-title[title='This user is silenced.']",
        visible: :all,
      )
    end

    it "records the penalty in the timeline" do
      review_page.visit_reviewable(reviewable)
      review_page.click_timeline_tab

      expect(page).to have_css(".timeline-event__title", text: "Author silenced automatically")
    end

    it "lifts the silence without resolving the flag" do
      review_page.visit_reviewable(reviewable)

      find(".reviewable-action.post-unsilence-user").click

      expect(page).to have_no_css(
        ".review-item__meta-flagged-user .d-icon-microphone-slash",
        visible: :all,
      )
      expect(author.reload).not_to be_silenced
      expect(reviewable.reload).to be_pending
    end

    it "names the surviving penalty after an action that keeps it" do
      review_page.visit_reviewable(reviewable)

      review_page.select_bundled_action(reviewable, "post-delete_and_agree", bundle_index: 1)

      expect(page).to have_css(".fk-d-default-toast__message", text: "spammer99 is still silenced.")
      expect(author.reload).to be_silenced
    end

    it "keeps only the newest undo toast when several flags share an author" do
      other_post = Fabricate(:post, user: author, topic: flagged_post.topic)
      other_reviewable = PostActionCreator.spam(flagger, other_post).reviewable
      other_post.update!(hidden: true, hidden_at: Time.zone.now)

      page.visit("/review")

      review_page.select_bundled_action(reviewable, "post-delete_and_agree", bundle_index: 1)
      expect(page).to have_css(".fk-d-default-toast__title", text: "Post deleted.")

      review_page.select_bundled_action(
        other_reviewable,
        "post-agree_and_keep_hidden",
        bundle_index: 1,
      )
      expect(page).to have_css(".fk-d-default-toast__title", text: "Post kept hidden.")

      expect(page).to have_css(".reviewable-undo-penalty", count: 1)
    end

    it "offers an undo on that toast" do
      review_page.visit_reviewable(reviewable)

      review_page.select_bundled_action(reviewable, "post-delete_and_agree", bundle_index: 1)
      find(".reviewable-undo-penalty").click

      expect(page).to have_css(
        ".fk-d-default-toast__message",
        text: "spammer99 is no longer silenced.",
      )
      expect(author.reload).not_to be_silenced
    end
  end
end
