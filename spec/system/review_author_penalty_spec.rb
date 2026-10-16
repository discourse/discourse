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
    expect(
      browser_root.locator(".review-item__meta-flagged-user .d-icon-microphone-slash"),
    ).to have_count(0)
    expect(
      browser_root.locator(".reviewable-action.post-unsilence-user").filter(visible: true),
    ).to have_count(0)
  end

  context "when automated tooling silenced the author for this post" do
    before do
      flagged_post.update!(hidden: true, hidden_at: Time.zone.now)
      silence_author!
    end

    it "marks the flagged user as silenced" do
      review_page.visit_reviewable(reviewable)

      expect(
        browser_root.locator(".review-item__meta-flagged-user .d-icon-microphone-slash"),
      ).not_to have_count(0)
      expect(
        browser_root.locator(
          ".review-item__meta-flagged-user .svg-icon-title[title='This user is silenced.']",
        ),
      ).not_to have_count(0)
    end

    it "records the penalty in the timeline" do
      review_page.visit_reviewable(reviewable)
      review_page.click_timeline_tab

      expect(browser_root.locator(".timeline-event__title").filter(visible: true)).to contain_text(
        [browser_text_pattern("Author silenced automatically")],
        useInnerText: true,
      )
    end

    it "lifts the silence without resolving the flag" do
      review_page.visit_reviewable(reviewable)

      browser_root.locator(".reviewable-action.post-unsilence-user").filter(visible: true).click

      expect(
        browser_root.locator(".review-item__meta-flagged-user .d-icon-microphone-slash"),
      ).to have_count(0)
      expect(author.reload).not_to be_silenced
      expect(reviewable.reload).to be_pending
    end

    it "names the surviving penalty after an action that keeps it" do
      review_page.visit_reviewable(reviewable)

      review_page.select_bundled_action(reviewable, "post-delete_and_agree", bundle_index: 1)

      expect(
        browser_root.locator(".fk-d-default-toast__message").filter(visible: true),
      ).to contain_text([browser_text_pattern("spammer99 is still silenced.")], useInnerText: true)
      expect(author.reload).to be_silenced
    end

    it "keeps only the newest undo toast when several flags share an author" do
      other_post = Fabricate(:post, user: author, topic: flagged_post.topic)
      other_reviewable = PostActionCreator.spam(flagger, other_post).reviewable
      other_post.update!(hidden: true, hidden_at: Time.zone.now)

      browser_page.goto("/review").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      review_page.select_bundled_action(reviewable, "post-delete_and_agree", bundle_index: 1)
      expect(
        browser_root.locator(".fk-d-default-toast__title").filter(visible: true),
      ).to contain_text([browser_text_pattern("Post deleted.")], useInnerText: true)

      review_page.select_bundled_action(
        other_reviewable,
        "post-agree_and_keep_hidden",
        bundle_index: 1,
      )
      expect(
        browser_root.locator(".fk-d-default-toast__title").filter(visible: true),
      ).to contain_text([browser_text_pattern("Post kept hidden.")], useInnerText: true)

      expect(browser_root.locator(".reviewable-undo-penalty").filter(visible: true)).to have_count(
        1,
      )
    end

    it "offers an undo on that toast" do
      review_page.visit_reviewable(reviewable)

      review_page.select_bundled_action(reviewable, "post-delete_and_agree", bundle_index: 1)
      browser_root.locator(".reviewable-undo-penalty").filter(visible: true).click

      expect(
        browser_root.locator(".fk-d-default-toast__message").filter(visible: true),
      ).to contain_text(
        [browser_text_pattern("spammer99 is no longer silenced.")],
        useInnerText: true,
      )
      expect(author.reload).not_to be_silenced
    end
  end
end
