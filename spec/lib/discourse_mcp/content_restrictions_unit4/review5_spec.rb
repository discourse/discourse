# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

  before do
    SiteSetting.unique_posts_mins = 0
    Discourse.stubs(:current_hostname).returns("review-five-site.example")
    Discourse.stubs(:base_url).returns("https://review-five-site.example")
  end

  {
    ideographic_full_stop: "review-five-site\u3002example",
    fullwidth_full_stop: "review-five-site\uFF0Eexample",
    halfwidth_ideographic_full_stop: "review-five-site\uFF61example",
    percent_encoded_ideographic_full_stop: "review-five-site%E3%80%82example",
    percent_encoded_fullwidth_full_stop: "review-five-site%EF%BC%8Eexample",
    percent_encoded_halfwidth_ideographic_full_stop: "review-five-site%EF%BD%A1example",
    percent_encoded_zero_width_space: "review-five-s%E2%80%8Bite.example",
    percent_encoded_soft_hyphen: "review-five-s%C2%ADite.example",
  }.each do |shape, link_host|
    %i[forum pm].each do |rule|
      it "[cr-u4] refuses a labelled #{shape} internal host under #{rule} without persisting content" do
        destination = Fabricate(:topic, id: 112_850_001, category: restricted_category)
        href = "https://#{link_host}/t/secret/#{destination.id}"
        raw = "Read [garden notes](#{href}) for seasonal observations."
        args = topic_arguments(raw:)
        isolated do
          data = expect_success(rpc("discourse_create_topic", args))
          written = Post.find(data.fetch("id"))
          anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
          expect(written.raw).to eq(raw)
          expect(anchor.text).to eq("garden notes")
          expect(anchor["href"]).to include("/t/secret/#{destination.id}")
          expect(anchor["href"]).to eq(href) if link_host.include?("%")
        end

        activate!(rule)
        expected = reference_error
        before_state = content_state
        response = rpc("discourse_create_topic", args)
        aggregate_failures do
          expect_reference_refusal(response)
          expect(response).to eq(expected), "BROWSER HOST: labelled #{shape} link was accepted"
          expect(content_state).to eq(before_state),
          "BROWSER HOST ATOMICITY: labelled #{shape} link persisted content"
        end
      end
    end
  end

  %i[forum pm].each do |rule|
    it "[cr-u4] accepts a labelled external ASCII host under #{rule}" do
      activate!(rule)
      raw = McpContentRestrictionsUnit4::LABELLED_LINK
      data = expect_success(rpc("discourse_create_topic", topic_arguments(raw:)))
      written = Post.find(data.fetch("id"))
      anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
      expect(written.raw).to eq(raw)
      expect(anchor["href"]).to eq("https://external.example/page")
    end
  end

  def review5_queued_reply
    Fabricate(
      :reviewable_queued_post,
      id: 112_850_020,
      topic: post.topic,
      category: allowed_category,
      target_created_by: recipient,
      payload: {
        raw: McpContentRestrictionsUnit4::PROSE,
        archetype: "regular",
      },
    )
  end

  def review5_revise(reviewable)
    rpc(
      "discourse_perform_reviewable_action",
      { reviewable_id: reviewable.id, action_id: "revise_and_reject_post", confirm: true },
    )
  end

  it "[cr-u4] refuses revise_and_reject_post under private_messages without persisting a system PM" do
    reviewable = review5_queued_reply
    activate!(:pm)
    expected = reference_error
    before_state = content_state
    before_pm_ids = Topic.with_deleted.where(archetype: Archetype.private_message).pluck(:id)
    response = review5_revise(reviewable)
    aggregate_failures do
      expect_reference_refusal(response)
      expect(response).to eq(expected), "SYSTEM PM: revise_and_reject_post was accepted"
      expect(Topic.with_deleted.where(archetype: Archetype.private_message).pluck(:id)).to eq(
        before_pm_ids,
      ),
      "SYSTEM PM ATOMICITY: revise_and_reject_post persisted a private message"
      expect(content_state).to eq(before_state),
      "SYSTEM PM ATOMICITY: reviewable or content changed"
    end
  end

  it "[cr-u4] permits revise_and_reject_post on an allowed target under the forum rule alone" do
    reviewable = review5_queued_reply
    activate!
    before_pm_ids = Topic.with_deleted.where(archetype: Archetype.private_message).pluck(:id)
    target_post_ids = post.topic.posts.pluck(:id)
    data = expect_success(review5_revise(reviewable))
    expect(data.fetch("reviewable_id")).to eq(reviewable.id)
    expect(reviewable.reload.status).to eq("rejected")
    message = Topic.where(archetype: Archetype.private_message).where.not(id: before_pm_ids).sole
    expect(message.subtype).to eq(TopicSubtype.system_message)
    expect(message.topic_allowed_users.pluck(:user_id)).to include(recipient.id)
    expect(message.first_post.raw).to include(reviewable.payload.fetch("raw"))
    expect(post.topic.posts.pluck(:id)).to eq(target_post_ids)
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
