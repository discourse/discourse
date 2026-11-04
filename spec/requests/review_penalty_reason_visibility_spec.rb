# frozen_string_literal: true

RSpec.describe "Review penalty reason visibility" do
  fab!(:moderator)
  fab!(:category_moderator, :user)
  fab!(:author, :user)
  fab!(:group)
  fab!(:category)
  fab!(:category_moderation_group) do
    Fabricate(:category_moderation_group, category: category, group: group)
  end
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic, user: author) }

  before do
    SiteSetting.enable_category_group_moderation = true
    group.add(category_moderator)
    author.update!(
      silenced_till: 1.month.from_now,
      suspended_at: 1.day.ago,
      suspended_till: 1.month.from_now,
    )
    UserHistory.create!(
      action: UserHistory.actions[:silence_user],
      acting_user_id: moderator.id,
      target_user_id: author.id,
      details: "Confidential silencing explanation",
    )
    UserHistory.create!(
      action: UserHistory.actions[:suspend_user],
      acting_user_id: moderator.id,
      target_user_id: author.id,
      details: "Confidential suspension explanation",
    )
  end

  shared_examples "penalty reason visibility" do |reviewable_type|
    context "with #{reviewable_type}" do
      let!(:reviewable) do
        attributes = { topic: post.topic, category: category, target_created_by: author }
        attributes[:target] = post if reviewable_type == :reviewable_flagged_post
        Fabricate(reviewable_type, **attributes)
      end

      it "withholds hidden reasons from category moderators in list and detail responses" do
        SiteSetting.hide_silencing_reasons = true
        SiteSetting.hide_suspension_reasons = true
        sign_in(category_moderator)

        ["/review.json", "/review/#{reviewable.id}.json"].each do |path|
          get path

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          item = json["reviewable"] || json["reviewables"].find { |r| r["id"] == reviewable.id }
          expect(item["id"]).to eq(reviewable.id)
          expect(item["author_penalties"].map { |penalty| penalty["kind"] }).to contain_exactly(
            "silence",
            "suspension",
          )
          aggregate_failures do
            expect(response.body).not_to include(author.silence_reason)
            expect(response.body).not_to include(author.suspend_reason)
            expect(item["author_penalties"]).to all(satisfy { |penalty| !penalty.key?("reason") })
            serialized_author = json["users"].find { |user| user["id"] == author.id }
            expect(serialized_author).to include("silenced_till", "suspended_till")
            expect(serialized_author).not_to have_key("silence_reason")
            expect(serialized_author).not_to have_key("suspend_reason")
          end
        end
      end

      it "preserves public reasons and staff access to hidden reasons" do
        sign_in(category_moderator)

        [false, true].each do |hidden|
          SiteSetting.hide_silencing_reasons = hidden
          SiteSetting.hide_suspension_reasons = hidden
          sign_in(moderator) if hidden

          get "/review/#{reviewable.id}.json"

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          expect(
            json["reviewable"]["author_penalties"].map { |penalty| penalty["reason"] },
          ).to contain_exactly(author.silence_reason, author.suspend_reason)
          expect(json["users"].find { |user| user["id"] == author.id }).to include(
            "silence_reason" => author.silence_reason,
            "suspend_reason" => author.suspend_reason,
          )
        end
      end
    end
  end

  include_examples "penalty reason visibility", :reviewable_flagged_post
  include_examples "penalty reason visibility", :reviewable_queued_post
end
