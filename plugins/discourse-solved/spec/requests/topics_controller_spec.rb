# frozen_string_literal: true

require "rails_helper"

RSpec.describe TopicsController do
  let(:p1) { Fabricate(:post, like_count: 1) }
  let(:topic) { p1.topic }
  let(:p2) { Fabricate(:post, like_count: 2, topic: topic, user: Fabricate(:user)) }

  def schema_json(answerCount)
    if answerCount > 0
      answer_json =
        ',"acceptedAnswer":{"@type":"Answer","text":"%{answer_text}","upvoteCount":%{answer_likes},"datePublished":"%{answered_at}","url":"%{answer_url}","author":{"@type":"Person","name":"%{username2}","url":"%{user2_url}"}}' %
          {
            answer_text: p2.excerpt,
            answer_likes: p2.like_count,
            answered_at: p2.created_at.as_json,
            answer_url: p2.full_url,
            username2: p2.user&.username,
            user2_url: p2.user&.full_url,
          }
    else
      answer_json = ""
    end

    '<script type="application/ld+json">{"@context":"http://schema.org","@type":"QAPage","name":"%{title}","mainEntity":{"@type":"Question","name":"%{title}","text":"%{question_text}","upvoteCount":%{question_likes},"answerCount":%{answerCount},"datePublished":"%{created_at}","author":{"@type":"Person","name":"%{username1}","url":"%{user1_url}"}%{answer_json}}}</script>' %
      # rubocop:enable Layout/LineLength
      {
        title: topic.title,
        question_text: p1.excerpt,
        question_likes: p1.like_count,
        answerCount: answerCount,
        created_at: topic.created_at.as_json,
        username1: topic.user&.username,
        user1_url: topic.user&.full_url,
        answer_json: answer_json,
      }
  end

  context "with solved enabled on every topic" do
    before { SiteSetting.allow_solved_on_all_topics = true }

    it "should include correct schema information in header" do
      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).to include(schema_json(0))

      Fabricate(:solved_topic, topic: topic, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).to include(schema_json(1))
    end

    it "should include quoted content in schema information" do
      post = topic.first_post
      post.raw = "[quote]This is a quoted text.[/quote]"
      post.save!
      post.rebake!

      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).to include('"text":"This is a quoted text."')
    end

    it "should include user name in output with the corresponding site setting" do
      SiteSetting.display_name_on_posts = true
      SiteSetting.show_who_marked_solved = true
      accepter = Fabricate(:user)
      Fabricate(:solved_topic, topic: topic, answer_post: p2, accepter:)

      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.parsed_body["accepted_answer"]["name"]).to eq(p2.user.name)
      expect(response.parsed_body["accepted_answer"]["username"]).to eq(p2.user.username)
      expect(response.parsed_body["accepted_answer"]["accepter_name"]).to eq(accepter.name)
      expect(response.parsed_body["accepted_answer"]["accepter_username"]).to eq(accepter.username)

      SiteSetting.show_who_marked_solved = false
      get "/t/#{topic.slug}/#{topic.id}.json"
      expect(response.parsed_body["accepted_answer"]["accepter_name"]).to eq(nil)
      expect(response.parsed_body["accepted_answer"]["accepter_username"]).to eq(nil)

      # enable_names is default ON, this ensures disabling it also disables names here
      SiteSetting.enable_names = false
      get "/t/#{topic.slug}/#{topic.id}.json"
      expect(response.parsed_body["accepted_answer"]["name"]).to eq(nil)
      expect(response.parsed_body["accepted_answer"]["accepter_name"]).to eq(nil)
    end

    it "should not include user name when site setting is disabled" do
      SiteSetting.display_name_on_posts = false
      Fabricate(:solved_topic, topic: topic, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.parsed_body["accepted_answer"]["name"]).to eq(nil)
      expect(response.parsed_body["accepted_answer"]["username"]).to eq(p2.user.username)
    end
  end

  context "with solved enabled for topics with specific tags" do
    let(:tag) { Fabricate(:tag) }

    before { SiteSetting.enable_solved_tags = tag.name }

    it "includes the correct schema information" do
      DiscourseTagging.add_or_create_tags_by_name(topic, [tag.name])
      Fabricate(:solved_topic, topic: topic, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).to include(schema_json(1))
    end

    it "doesn't include solved schema information when the topic has a different tag" do
      another_tag = Fabricate(:tag)

      DiscourseTagging.add_or_create_tags_by_name(topic, [another_tag.name])
      Fabricate(:solved_topic, topic: topic, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).not_to include(schema_json(1))
    end
  end
end
