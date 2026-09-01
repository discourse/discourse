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
  end
end
