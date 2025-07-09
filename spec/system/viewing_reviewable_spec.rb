# frozen_string_literal: true

describe "Viewing reviewable item", type: :system do
  fab!(:admin)
  fab!(:group)
  fab!(:reviewable_flagged_post)

  let(:review_page) { PageObjects::Pages::Review.new }

  describe "when user is part of the groups list of the `reviewable_ui_refresh` site setting" do
    before do
      SiteSetting.reviewable_ui_refresh = group.name
      group.add(admin)
      sign_in(admin)
    end

    describe "when the reviewable item is a flagged post" do
      it "shows the new reviewable UI" do
        review_page.visit_reviewable(reviewable_flagged_post)

        expect(page).to have_selector(".review-container")
      end

      it "shows the reviewable item with badges stating the flag reason and count" do
        _spam_reviewable_score =
          Fabricate(
            :reviewable_score,
            reviewable: reviewable_flagged_post,
            reviewable_score_type: ReviewableScore.types[:spam],
          )

        _off_topic_reviewable_score =
          Fabricate(
            :reviewable_score,
            reviewable: reviewable_flagged_post,
            reviewable_score_type: ReviewableScore.types[:off_topic],
          )

        _illegal_reviewable_score =
          Fabricate(
            :reviewable_score,
            reviewable: reviewable_flagged_post,
            reviewable_score_type: ReviewableScore.types[:illegal],
          )

        _inappropriate_reviewable_score =
          Fabricate(
            :reviewable_score,
            reviewable: reviewable_flagged_post,
            reviewable_score_type: ReviewableScore.types[:inappropriate],
          )

        _needs_approval_reviewable_score =
          Fabricate(
            :reviewable_score,
            reviewable: reviewable_flagged_post,
            reviewable_score_type: ReviewableScore.types[:needs_approval],
          )

        flag_reason_component =
          review_page.visit_reviewable(reviewable_flagged_post).flag_reason_component

        expect(flag_reason_component).to have_spam_flag_reason(reviewable_flagged_post, count: 1)
        expect(flag_reason_component).to have_off_topic_flag_reason(
          reviewable_flagged_post,
          count: 1,
        )
        expect(flag_reason_component).to have_illegal_flag_reason(reviewable_flagged_post, count: 1)

        expect(flag_reason_component).to have_inappropriate_flag_reason(
          reviewable_flagged_post,
          count: 2,
        )

        expect(flag_reason_component).to have_needs_approval_flag_reason(
          reviewable_flagged_post,
          count: 1,
        )
      end

      it "shows the topic status, title link, category badge and tags of the topic associated with the reviewable item correctly" do
        post = reviewable_flagged_post.post
        topic = reviewable_flagged_post.topic
        category = Fabricate(:category)
        topic.change_category_to_id(category.id)
        tag_1 = Fabricate(:tag)
        tag_2 = Fabricate(:tag)
        topic.tags = [tag_1, tag_2]
        topic.closed = true
        topic.save!

        topic_link_component =
          review_page.visit_reviewable(reviewable_flagged_post).topic_link_component

        expect(topic_link_component).to have_closed_topic_status

        expect(topic_link_component).to have_topic_link(
          topic_title: topic.title,
          post_url: post.full_url,
        )

        expect(topic_link_component).to have_category_badge(category.name)
        expect(topic_link_component).to have_tag_link(tag_name: tag_1.name, tag_url: tag_1.url)
        expect(topic_link_component).to have_tag_link(tag_name: tag_2.name, tag_url: tag_2.url)

        # TODO: Add test for watched words highlighting
      end
    end
  end
end
