# frozen_string_literal: true

RSpec.describe TopicsController do
  let(:p1) { Fabricate(:post, like_count: 1) }
  let(:topic) { p1.topic }
  let(:p2) { Fabricate(:post, like_count: 2, topic:, user: Fabricate(:user)) }

  def expected_schema_json
    answer_json =
      ',"acceptedAnswer":{"@type":"Answer","author":{"@type":"Person","name":"%{username2}","url":"%{user2_url}"},"dateModified":"%{answer_modified}","datePublished":"%{answered_at}","text":"%{answer_text}","upvoteCount":%{answer_likes},"url":"%{answer_url}"}' %
        {
          answer_text: p2.excerpt,
          answer_likes: p2.like_count,
          answered_at: p2.created_at.as_json,
          answer_modified: (p2.last_version_at || p2.created_at).as_json,
          answer_url: p2.full_url,
          username2: p2.user&.username,
          user2_url: p2.user&.full_url,
        }

    '<script type="application/ld+json">{"@context":"http://schema.org","@type":"QAPage","name":"%{title}","datePublished":"%{created_at}","mainEntity":{"@type":"Question","answerCount":1,"author":{"@type":"Person","name":"%{username1}","url":"%{user1_url}"},"dateModified":"%{question_modified}","datePublished":"%{created_at}","name":"%{title}","text":"%{question_text}","upvoteCount":%{question_likes}%{answer_json}}}</script>' %
      # rubocop:enable Layout/LineLength
      {
        title: topic.title,
        question_text: p1.excerpt,
        question_likes: p1.like_count,
        created_at: topic.created_at.as_json,
        question_modified: (p1.last_version_at || p1.created_at).as_json,
        username1: topic.user&.username,
        user1_url: topic.user&.full_url,
        answer_json:,
      }
  end

  context "with solved enabled on every topic" do
    before { SiteSetting.allow_solved_on_all_topics = true }

    it "should not include schema information for single-post topics without answers" do
      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).not_to include("QAPage")
    end

    it "should include correct schema information when topic has an accepted answer" do
      Fabricate(:solved_topic, topic:, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).to include(expected_schema_json)
    end

    it "should include quoted content in schema information" do
      Fabricate(:solved_topic, topic:, answer_post: p2)

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
      Fabricate(:solved_topic, topic:, answer_post: p2, accepter:)

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
      Fabricate(:solved_topic, topic:, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.parsed_body["accepted_answer"]["name"]).to eq(nil)
      expect(response.parsed_body["accepted_answer"]["username"]).to eq(p2.user.username)
    end
  end

  describe "crawler schema modifiers" do
    let(:crawler_env) { { "HTTP_USER_AGENT" => "Googlebot" } }

    before { SiteSetting.allow_solved_on_all_topics = true }

    def parsed_crawler_body
      Nokogiri::HTML5.fragment(response.body)
    end

    it "uses Question schema instead of DiscussionForumPosting when topic has replies" do
      Fabricate(:post, topic:, user: Fabricate(:user))

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      expect(doc.css('[itemtype*="Question"]').size).to eq(1)
      expect(doc.css('[itemtype*="DiscussionForumPosting"]').size).to eq(0)
    end

    it "keeps DiscussionForumPosting for single-post topics" do
      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      expect(doc.css('[itemtype*="DiscussionForumPosting"]').size).to eq(1)
      expect(doc.css('[itemtype*="QAPage"]').size).to eq(0)
    end

    it "keeps DiscussionForumPosting when only replies are hidden" do
      Fabricate(:post, topic:, hidden: true)

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      expect(doc.css('[itemtype*="DiscussionForumPosting"]').size).to eq(1)
      expect(doc.css('[itemtype*="QAPage"]').size).to eq(0)
    end

    it "keeps DiscussionForumPosting when only replies are small action posts" do
      Fabricate(:post, topic:, post_type: Post.types[:small_action])

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      expect(doc.css('[itemtype*="DiscussionForumPosting"]').size).to eq(1)
      expect(doc.css('[itemtype*="QAPage"]').size).to eq(0)
    end

    it "emits valid QAPage microdata with all required schema.org properties" do
      p3 = Fabricate(:post, topic:, user: Fabricate(:user))
      Fabricate(:solved_topic, topic:, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      qa_page = doc.at_css('[itemtype*="QAPage"]')
      expect(qa_page).to be_present
      expect(qa_page.at_css('> [itemprop="name"]')["content"]).to eq(topic.title)

      question = doc.at_css('[itemtype*="Question"]')
      expect(question).to be_present
      expect(question.at_css('[itemprop="name"]')["content"]).to eq(topic.title)
      expect(question.at_css('[itemprop="datePublished"]')["content"]).to be_present
      expect(question.at_css('[itemprop="answerCount"]')["content"]).to eq("2")
      expect(question.at_css('[itemprop="upvoteCount"]')["content"]).to eq(p1.like_count.to_s)
      expect(question.at_css('[itemprop="text"]')).to be_present
      expect(question.at_css('[itemprop="author"] [itemprop="name"]')).to be_present

      accepted = doc.at_css("#post_#{p2.post_number}")
      expect(accepted["itemprop"]).to eq("acceptedAnswer")
      expect(accepted["itemtype"]).to include("Answer")
      expect(accepted.at_css('[itemprop="text"]')).to be_present
      expect(accepted.at_css('[itemprop="datePublished"]')).to be_present
      expect(accepted.at_css('[itemprop="author"] [itemprop="name"]')).to be_present
      expect(accepted.at_css('[itemprop="author"] [itemprop="url"]')["content"]).to include(
        p2.user.username,
      )
      expect(accepted.at_css('[itemprop="upvoteCount"]')["content"]).to eq(p2.like_count.to_s)
      accepted_urls = accepted.css('meta[itemprop="url"]').map { |el| el["content"] }
      expect(accepted_urls).to include(p2.full_url)

      suggested = doc.at_css("#post_#{p3.post_number}")
      expect(suggested["itemprop"]).to eq("suggestedAnswer")
      expect(suggested["itemtype"]).to include("Answer")
      expect(suggested.at_css('[itemprop="text"]')).to be_present
      expect(suggested.at_css('[itemprop="datePublished"]')).to be_present
      expect(suggested.at_css('[itemprop="author"] [itemprop="name"]')).to be_present
      expect(suggested.at_css('[itemprop="author"] [itemprop="url"]')["content"]).to include(
        p3.user.username,
      )
      expect(suggested.at_css('[itemprop="upvoteCount"]')["content"]).to eq(p3.like_count.to_s)
      suggested_urls = suggested.css('meta[itemprop="url"]').map { |el| el["content"] }
      expect(suggested_urls).to include(p3.full_url)
    end

    it "does not leak microdata from ineligible posts into the Question scope" do
      ineligible =
        Fabricate(:post, topic:, user: Fabricate(:user), post_type: Post.types[:moderator_action])
      Fabricate(:solved_topic, topic:, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      question = doc.at_css('[itemtype*="Question"]')
      ineligible_node = doc.at_css("#post_#{ineligible.post_number}")

      expect(ineligible_node).to be_present
      expect(question.xpath('./*[@itemprop="datePublished"]').size).to eq(1)
      expect(ineligible_node.css("[itemprop]")).to be_empty
    end

    it "does not modify schema for topics without solved enabled" do
      SiteSetting.allow_solved_on_all_topics = false

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      expect(doc.css('[itemtype*="DiscussionForumPosting"]').size).to eq(1)
      expect(doc.css('[itemtype*="Question"]').size).to eq(0)
    end

    it "does not emit QAPage schema when schema markup is set to never" do
      SiteSetting.solved_add_schema_markup = "never"

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      expect(doc.css('[itemtype*="DiscussionForumPosting"]').size).to eq(1)
      expect(doc.css('[itemtype*="QAPage"]').size).to eq(0)
      expect(doc.css('[itemtype*="Question"]').size).to eq(0)
    end

    it "does not emit QAPage schema when set to 'answered only' without an accepted answer" do
      SiteSetting.solved_add_schema_markup = "answered only"

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      expect(doc.css('[itemtype*="DiscussionForumPosting"]').size).to eq(1)
      expect(doc.css('[itemtype*="QAPage"]').size).to eq(0)
    end

    it "emits QAPage schema when set to 'answered only' with an accepted answer" do
      SiteSetting.solved_add_schema_markup = "answered only"
      Fabricate(:solved_topic, topic:, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}", env: crawler_env
      doc = parsed_crawler_body

      expect(doc.css('[itemtype*="QAPage"]').size).to eq(1)
      expect(doc.css('[itemtype*="Question"]').size).to eq(1)
    end
  end

  context "with solved enabled for topics with specific tags" do
    let(:tag) { Fabricate(:tag) }

    before { SiteSetting.enable_solved_tags = tag.name }

    it "includes the correct schema information" do
      DiscourseTagging.add_or_create_tags_by_name(topic, [tag.name])
      Fabricate(:solved_topic, topic:, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).to include(expected_schema_json)
    end

    it "doesn't include solved schema information when the topic has a different tag" do
      another_tag = Fabricate(:tag)

      DiscourseTagging.add_or_create_tags_by_name(topic, [another_tag.name])
      Fabricate(:solved_topic, topic:, answer_post: p2)

      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.body).not_to include(expected_schema_json)
    end
  end
end
