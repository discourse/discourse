# frozen_string_literal: true

describe TopicsController do
  fab!(:topic)
  fab!(:llm_model, :fake_model)
  fab!(:summarization_agent) do
    Fabricate(:ai_agent, allowed_group_ids: [Group::AUTO_GROUPS[:admins]])
  end
  fab!(:first_post) { Fabricate(:post, topic: topic, post_number: 1) }

  let(:summary_phrase) { "concise overview" }
  let(:summary_text) { "A **#{summary_phrase}** of this discussion." }
  let(:crawler_headers) { { "User-Agent" => "Googlebot" } }
  let(:browser_headers) { { "User-Agent" => "Mozilla/5.0 Chrome/130.0.0.0 Safari/537.36" } }

  before do
    enable_current_plugin
    SiteSetting.ai_default_llm_model = llm_model.id
    SiteSetting.ai_summarization_agent = summarization_agent.id
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.enable_markdown_endpoints = true
    SiteSetting.ai_summary_backfill_maximum_topics_per_hour = 10
    SiteSetting.ai_summaries_for_crawlers = true
  end

  def create_summary(locale: "en", text: summary_text)
    strategy = DiscourseAi::Summarization::Strategies::TopicSummary.new(topic, locale:)
    Fabricate(
      :ai_summary,
      target: topic,
      locale:,
      summarized_text: text,
      original_content_sha: strategy.summary_fingerprint[:original_content_sha],
      highest_target_number: topic.highest_post_number,
    )
  end

  describe "#show" do
    it "keeps forced crawler translations consistent on misses and shared cache hits" do
      global_setting :anon_cache_store_threshold, 1
      Middleware::AnonymousCache.enable_anon_cache
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "fr"
      SiteSetting.default_locale = "fr"
      topic.update!(locale: "en")
      first_post.update!(locale: "en")
      Fabricate(:post_localization, post: first_post, locale: "fr", cooked: "<p>Bonjour</p>")
      create_summary
      french = create_summary(locale: "fr", text: "Un résumé de cette discussion.")
      forced_headers = browser_headers.merge("Discourse-Render" => "crawler")
      bot_headers = { "User-Agent" => "#{browser_headers["User-Agent"]} Googlebot" }

      %w[true false].each do |translate|
        cookies[ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE] = translate
        [[forced_headers, bot_headers], [bot_headers, forced_headers]].each do |headers|
          Middleware::AnonymousCache.clear_all_cache!
          headers.each_with_index do |request_headers, index|
            get topic.relative_url, headers: request_headers

            expect(response.status).to eq(200)
            expect(response.headers["X-Discourse-Cached"]).to eq(index.zero? ? "store" : "true")
            document = Nokogiri.HTML5(response.body)
            expect(document.at_css('[itemprop="abstract"]').text).to include(
              translate == "true" ? french.summarized_text : summary_phrase,
            )
            expect(document.at_css("#post_1 .post").text).to include(
              translate == "true" ? "Bonjour" : first_post.raw,
            )
          end
        end
      end
    end

    it "publishes a cached summary as the discussion abstract in crawler HTML" do
      create_summary

      get topic.relative_url, headers: crawler_headers

      expect(response.status).to eq(200)
      document = Nokogiri.HTML5(response.body)
      abstract =
        document.at_css(
          '[itemtype="http://schema.org/DiscussionForumPosting"] > section [itemprop="abstract"]',
        )
      expect(abstract&.text).to include("A #{summary_phrase} of this discussion.")
      expect(abstract.at_css("strong").text).to eq(summary_phrase)
      expect(document.at_css("#post_1 .post").text).to include(first_post.raw)
    end

    it "leaves crawler Markdown responses unchanged" do
      create_summary

      get "#{topic.relative_url}.md", headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.body).not_to include("## AI-generated summary", summary_phrase)
      expect(response.body).to include(first_post.raw)
    end

    it "uses the same crawler classification as the anonymous cache" do
      global_setting :anon_cache_store_threshold, 1
      Middleware::AnonymousCache.enable_anon_cache
      Middleware::AnonymousCache.clear_all_cache!
      create_summary

      get topic.relative_url, headers: browser_headers.merge("Discourse-Render" => "crawler")

      expect(response.headers["X-Discourse-Cached"]).to eq("store")
      expect(response.body).to include(summary_phrase)

      get topic.relative_url,
          headers: {
            "User-Agent" => "#{browser_headers["User-Agent"]} Googlebot",
          }

      expect(response.headers["X-Discourse-Cached"]).to eq("true")
      expect(response.body).to include(summary_phrase)
    end

    context "with HTML publication" do
      def request_topic(path: topic.relative_url, params: {})
        get path, params:, headers: crawler_headers
      end

      it "serves stored cooked content rather than cooking the source on request" do
        summary = create_summary
        stored_content = "Previously cooked overview"
        summary.update_columns(summarized_cooked: "<p>#{stored_content}</p>")

        request_topic

        expect(response.status).to eq(200)
        expect(response.body).to include(stored_content)
        expect(response.body).not_to include(summary_phrase)
      end

      it "omits uncooked summaries without cooking them on request" do
        summary = create_summary
        summary.update_columns(summarized_cooked: nil)

        request_topic

        expect(response.status).to eq(200)
        expect(response.body).to include(first_post.raw)
        expect(response.body).not_to include(summary_phrase)
        expect(summary.reload.summarized_cooked).to be_nil

        summary.update_columns(summarized_cooked: "<p>#{summary_phrase}</p>")
        request_topic

        expect(response.body).to include(summary_phrase)
      end

      it "leaves browser and print responses unchanged" do
        create_summary
        path = topic.relative_url

        [{}, { print: true }].each do |params|
          SiteSetting.ai_summaries_for_crawlers = false
          get path, params: params, headers: browser_headers
          original_last_modified = response.headers["Last-Modified"]
          SiteSetting.ai_summaries_for_crawlers = true

          get path, params: params, headers: browser_headers

          expect(response.status).to eq(200)
          expect(response.body).not_to include(summary_phrase)
          expect(response.headers["Last-Modified"]).to eq(original_last_modified)
        end
      end

      it "adds one summary lookup per request without retaining it across requests" do
        create_summary
        SiteSetting.ai_summaries_for_crawlers = false
        baseline_queries = track_sql_queries { request_topic }
        SiteSetting.ai_summaries_for_crawlers = true

        queries = track_sql_queries { request_topic }

        expect(response.status).to eq(200)
        expect(response.body).to include(summary_phrase)
        summary_query = /SELECT.*FROM "ai_summaries"/
        expect(queries.grep(summary_query).size).to eq(
          baseline_queries.grep(summary_query).size + 1,
        )

        AiSummary.where(target: topic).delete_all
        request_topic

        expect(response.status).to eq(200)
        expect(response.body).not_to include(summary_phrase)

        create_summary
        request_topic

        expect(response.status).to eq(200)
        expect(response.body).to include(summary_phrase)
      end

      it "serves summaries through the existing anonymous topic cache" do
        global_setting :anon_cache_store_threshold, 1
        Middleware::AnonymousCache.enable_anon_cache
        Middleware::AnonymousCache.clear_all_cache!
        summary = create_summary

        request_topic

        expect(response.headers["X-Discourse-Cached"]).to eq("store")
        expect(request.env["ANON_CACHE_DURATION"]).to eq(1.minute)
        expect(response.body).to include(summary_phrase)

        path = topic.relative_url
        get path, headers: browser_headers
        expect(response.headers["X-Discourse-Cached"]).to eq("store")
        expect(response.body).not_to include(summary_phrase)

        get path, headers: browser_headers
        expect(response.headers["X-Discourse-Cached"]).to eq("true")
        expect(response.body).not_to include(summary_phrase)

        first_post.update!(last_version_at: summary.updated_at + 1.minute)
        queries = track_sql_queries { request_topic }

        expect(response.headers["X-Discourse-Cached"]).to eq("true")
        expect(response.body).to include(summary_phrase)
        expect(queries.grep(/\b(?:ai_summaries|posts|topics)\b/)).to be_empty

        Middleware::AnonymousCache.clear_all_cache!
        request_topic

        expect(response.headers["X-Discourse-Cached"]).to eq("store")
        expect(response.body).not_to include(summary_phrase)

        request_topic

        expect(response.headers["X-Discourse-Cached"]).to eq("true")
        expect(response.body).not_to include(summary_phrase)
      end

      it "omits summaries when publication, summarization, or the plugin is disabled" do
        summary = create_summary

        %i[
          ai_summaries_for_crawlers
          ai_summarization_enabled
          discourse_ai_enabled
        ].each do |setting|
          SiteSetting.public_send("#{setting}=", false)
          request_topic

          expect(response.status).to eq(200)
          expect(response.body).not_to include(summary.summarized_text, summary_phrase)
          SiteSetting.public_send("#{setting}=", true)
        end
      end

      it "leaves a missing summary absent without generating one" do
        DiscourseAi::Completions::Llm.with_prepared_responses([]) do
          expect { request_topic }.not_to change(AiSummary, :count)
        end

        expect(response.status).to eq(200)
        expect(response.body).to include(first_post.raw)
        expect(response.body).not_to include(
          I18n.t("discourse_ai.summarization.published_summary_heading"),
        )
        expect(response.headers["Last-Modified"]).to eq(first_post.updated_at.httpdate)
        expect(request.env["ANON_CACHE_DURATION"]).to eq(1.minute)
      end

      it "omits an edited summary even for an admin and preserves the post freshness hint" do
        summary = create_summary
        sign_in(Fabricate(:admin))
        request_topic
        expect(response.body).to include(summary_phrase)

        first_post.update!(last_version_at: summary.updated_at + 1.minute)
        request_topic

        expect(response.status).to eq(200)
        expect(response.body).not_to include(summary_phrase)
        expect(response.headers["Last-Modified"]).to eq(first_post.reload.updated_at.httpdate)
      end

      it "omits a summary after new replies or hidden source posts change the input" do
        summary = create_summary
        reply = Fabricate(:post, topic:, post_number: 2)
        topic.update!(highest_post_number: 2)
        request_topic
        expect(response.body).not_to include(summary_phrase)

        summary.destroy!
        create_summary
        request_topic
        expect(response.body).to include(summary_phrase)

        reply.update!(hidden: true)
        request_topic
        expect(response.body).not_to include(summary_phrase)
      end

      it "omits a summary after a source post is deleted" do
        reply = Fabricate(:post, topic:, post_number: 2)
        topic.update!(highest_post_number: 2)
        create_summary
        request_topic
        expect(response.body).to include(summary_phrase)

        reply.trash!
        request_topic

        expect(response.status).to eq(200)
        expect(response.body).not_to include(summary_phrase)
        expect(response.headers["Last-Modified"]).to eq(first_post.reload.updated_at.httpdate)
      end

      it "omits restricted topics even when the requester is an admin" do
        create_summary
        topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
        sign_in(Fabricate(:admin))

        request_topic

        expect(response.status).to eq(200)
        expect(response.body).to include(first_post.raw)
        expect(response.body).not_to include(summary_phrase)
      end

      it "omits summaries when the site requires login" do
        create_summary
        SiteSetting.login_required = true
        sign_in(Fabricate(:admin))

        request_topic

        expect(response.status).to eq(200)
        expect(response.body).not_to include(summary_phrase)
      end

      it "omits personal messages even when their participant can summarize" do
        admin = Fabricate(:admin)
        message = Fabricate(:private_message_topic, user: admin)
        message_post = Fabricate(:post, topic: message)
        strategy = DiscourseAi::Summarization::Strategies::TopicSummary.new(message, locale: "en")
        Fabricate(
          :ai_summary,
          target: message,
          locale: "en",
          summarized_text: summary_text,
          original_content_sha: strategy.summary_fingerprint[:original_content_sha],
        )
        SiteSetting.ai_pm_summarization_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
        sign_in(admin)

        request_topic(path: message.relative_url)

        expect(response.status).to eq(200)
        expect(response.body).to include(message_post.raw)
        expect(response.body).not_to include(summary_phrase)
      end

      it "omits summaries from later pages and single-post responses" do
        Fabricate.times(TopicView.chunk_size, :post, topic: topic, user: first_post.user)
        topic.update!(highest_post_number: TopicView.chunk_size + 1)
        create_summary

        request_topic(params: { page: 2 })
        expect(response.status).to eq(200)
        expect(response.body).not_to include(summary_phrase)

        request_topic(path: "#{topic.relative_url}/2")
        expect(response.status).to eq(200)
        expect(response.body).not_to include(summary_phrase)
      end

      it "leaves Last-Modified and topic activity unchanged when a summary is regenerated" do
        freeze_time
        topic.update!(last_posted_at: first_post.created_at)
        summary = create_summary
        request_topic
        previous_last_modified = response.headers["Last-Modified"]
        topic_activity = topic.reload.last_posted_at

        freeze_time 2.minutes.from_now
        summary.update!(summarized_text: "An updated overview")
        request_topic

        expect(response.body).to include(summary.summarized_text)
        expect(response.headers["Last-Modified"]).to eq(previous_last_modified)
        expect(topic.reload.last_posted_at).to eq_time(topic_activity)
        expect(request.env["ANON_CACHE_DURATION"]).to eq(1.minute)
      end

      it "uses the source-language summary instead of another cached locale" do
        topic.update!(locale: "fr")
        english = create_summary
        french = create_summary(locale: "fr", text: "Un résumé de cette discussion.")

        request_topic

        expect(response.status).to eq(200)
        expect(response.body).to include(french.summarized_text)
        expect(response.body).not_to include(english.summarized_text, summary_phrase)
      end

      it "uses a localized summary when the discussion is shown translated" do
        SiteSetting.content_localization_enabled = true
        SiteSetting.content_localization_supported_locales = "fr"
        SiteSetting.default_locale = "fr"
        topic.update!(locale: "en")
        first_post.update!(locale: "en")
        Fabricate(:post_localization, post: first_post, locale: "fr", cooked: "<p>Bonjour</p>")
        english = create_summary
        french = create_summary(locale: "fr", text: "Un résumé de cette discussion.")

        request_topic

        expect(response.status).to eq(200)
        expect(response.body).to include(french.summarized_text)
        expect(response.body).not_to include(english.summarized_text, summary_phrase)

        cookies[ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE] = "false"
        request_topic

        expect(response.body).to include(summary_phrase, first_post.raw)
        expect(response.body).not_to include(french.summarized_text, "Bonjour")

        cookies[ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE] = "true"
        french.destroy!
        request_topic
        expect(response.body).not_to include(
          english.summarized_text,
          french.summarized_text,
          summary_phrase,
        )
      end
    end

    it "sanitizes summary markup in HTML" do
      create_summary(
        text: 'Overview <script>alert("xss")</script> <a href="javascript:alert(1)">unsafe</a>',
      )

      get topic.relative_url, headers: crawler_headers
      abstract = Nokogiri.HTML5(response.body).at_css('[itemprop="abstract"]')
      expect(abstract.text).to include("Overview")
      expect(abstract.css("script, [href^='javascript:']")).to be_empty
    end

    it "leaves topic JSON unchanged" do
      summary = create_summary
      summary.update!(updated_at: first_post.updated_at + 1.minute)

      get "#{topic.relative_url}.json", headers: crawler_headers

      expect(response.status).to eq(200)
      expect(response.parsed_body["has_cached_summary"]).to eq(true)
      expect(response.parsed_body).not_to have_key("ai_summary")
      expect(response.headers["Last-Modified"]).to be_nil
    end

    it "keeps the abstract on QAPage rather than the nested question or answers" do
      SiteSetting.allow_solved_on_all_topics = true
      SiteSetting.solved_add_schema_markup = "always"
      Fabricate(:post, topic:, post_number: 2)
      topic.update!(highest_post_number: 2)
      create_summary

      get topic.relative_url, headers: crawler_headers

      expect(response.status).to eq(200)
      document = Nokogiri.HTML5(response.body)
      abstract = document.at_css('[itemprop="abstract"]')
      expect(abstract.ancestors("[itemscope]").first["itemtype"]).to eq("https://schema.org/QAPage")
      expect(
        document.css('[itemtype="https://schema.org/Question"] [itemprop="abstract"]'),
      ).to be_empty
    end
  end
end
