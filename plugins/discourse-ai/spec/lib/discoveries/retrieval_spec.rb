# frozen_string_literal: true

describe DiscourseAi::Discoveries::Retrieval do
  fab!(:user)
  fab!(:staff_user, :admin)
  fab!(:category)
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:topic_1) { Fabricate(:topic, category:) }
  fab!(:topic_2) { Fabricate(:topic, category:) }
  fab!(:topic_3) { Fabricate(:topic, category:) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:post_1) { Fabricate(:post, topic: topic_1, raw: "First useful answer") }
  fab!(:post_2) { Fabricate(:post, topic: topic_2, user: staff_user, raw: "Second useful answer") }
  fab!(:post_3) { Fabricate(:post, topic: topic_3, raw: "Third useful answer") }
  fab!(:embedding_definition)

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = embedding_definition.id
    SiteSetting.ai_embeddings_enabled = true
  end

  def source(post, excerpt: post.raw)
    {
      "topic_id" => post.topic_id,
      "post_id" => post.id,
      "post_number" => post.post_number,
      "title" => post.topic.title,
      "url" => post.relative_url,
      "excerpt" => excerpt,
      "post_updated_at" => post.updated_at.iso8601(6),
    }
  end

  describe "#call" do
    context "with a scope" do
      it "narrows both retrievals to the scope" do
        lexical_retriever = instance_spy(Proc, call: [source(post_1)])
        semantic_retriever = instance_spy(Proc, call: [source(post_2)])

        result =
          described_class.new(user:, lexical_retriever:, semantic_retriever:).call(
            "how do I reset my password",
            keyword_query: "reset password",
            semantic_query: "How can I reset a forgotten password?",
            scope_filter: "category:#{category.id}",
          )

        expect(lexical_retriever).to have_received(:call).with(
          "reset password category:#{category.id}",
        )
        expect(semantic_retriever).to have_received(:call).with(
          "How can I reset a forgotten password? category:#{category.id}",
        )
        expect(result.scope_fallback).to be_nil
      end

      it "searches the whole site when nothing matches inside the scope" do
        lexical_retriever = ->(query) { query.include?("category:") ? [] : [source(post_1)] }

        result =
          described_class.new(
            user:,
            lexical_retriever:,
            semantic_retriever: ->(_query) { [] },
          ).call("reset password", scope_filter: "category:#{category.id}")

        expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
          [topic_1.id],
        )
        expect(result.scope_fallback).to eq(true)
      end

      it "searches a personal message the reader is in as a message" do
        message = Fabricate(:private_message_topic, user:)
        message_post = Fabricate(:post, topic: message, user:, raw: "Widget reset steps")

        result =
          described_class.new(user:, lexical_retriever: ->(_query) { [source(message_post)] }).call(
            "widget",
            scope_filter: "topic:#{message.id}",
          )

        expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
          [message.id],
        )
        expect(result.scope_fallback).to be_nil
      end

      it "searches a topic post by post, without semantic retrieval" do
        SearchIndexer.enable
        widget_posts = [
          Fabricate(:post, topic: topic_1, raw: "Widgets need a reset after updating"),
          Fabricate(:post, topic: topic_1, raw: "Another widget tip: clear the cache"),
        ]
        widget_posts.each { |post| SearchIndexer.index(post, force: true) }
        semantic_retriever = instance_spy(Proc, call: [source(post_2)])

        result =
          described_class.new(user:, semantic_retriever:).call(
            "widget",
            scope_filter: "topic:#{topic_1.id}",
          )

        expect(semantic_retriever).not_to have_received(:call)
        expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
          [topic_1.id],
        )
        expect(result.candidates.first.fetch("passages").pluck("post_id")).to match_array(
          widget_posts.map(&:id),
        )
      ensure
        SearchIndexer.disable
      end
    end

    it "clears names from candidates when names are disabled" do
      SiteSetting.enable_names = false
      post_1.user.update!(name: "Hidden Author")
      retrieval =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1).merge("name" => post_1.user.name)] },
          semantic_retriever: ->(_query) { [] },
        )

      result = retrieval.call("useful")

      expect(result.candidates).to contain_exactly(
        include("username" => post_1.user.username, "name" => nil),
      )
    end

    it "uses semantic retrieval with embeddings configured even when full-page semantic search is disabled" do
      SiteSetting.ai_embeddings_semantic_search_enabled = false

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1)] },
          semantic_retriever: ->(_query) { [source(post_2)] },
        ).call("猫")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to contain_exactly(
        topic_1.id,
        topic_2.id,
      )
    end

    it "uses separate prepared queries for keyword and semantic retrieval" do
      lexical_retriever = instance_spy(Proc, call: [source(post_1)])
      semantic_retriever = instance_spy(Proc, call: [source(post_2)])

      result =
        described_class.new(user:, lexical_retriever:, semantic_retriever:).call(
          "怎么删除具备管理员权限的幽灵机器人用户？",
          keyword_query: "delete admin bot user",
          semantic_query: "how to remove a bot account with administrator permissions",
        )

      expect(lexical_retriever).to have_received(:call).with("delete admin bot user")
      expect(semantic_retriever).to have_received(:call).with(
        "how to remove a bot account with administrator permissions",
      )
      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to contain_exactly(
        topic_1.id,
        topic_2.id,
      )
    end

    it "uses only the prepared keyword query when it contains native search operators" do
      result =
        described_class.new(
          user:,
          lexical_retriever: ->(query) { query == "order:likes" ? [source(post_1)] : [] },
          semantic_retriever: ->(_query) { [source(post_2)] },
        ).call(
          "What are the 3 most popular topics on the forum?",
          keyword_query: "order:likes",
          semantic_query: "the most popular forum topics",
        )

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq([topic_1.id])
    end

    it "starts keyword and semantic retrieval concurrently" do
      started = Queue.new
      release = Queue.new
      retriever =
        lambda do |_query|
          started << true
          release.pop
          []
        end
      retrieval =
        described_class.new(user:, lexical_retriever: retriever, semantic_retriever: retriever)

      worker = Thread.new { retrieval.call("猫") }
      Timeout.timeout(1) { 2.times { started.pop } }
      2.times { release << true }

      expect(worker.value.candidates).to eq([])
    ensure
      2.times { release << true } if release
      worker&.join(1)
    end

    it "keeps results from one retrieval method when the other fails" do
      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { raise "keyword unavailable" },
          semantic_retriever: ->(_query) { [source(post_2)] },
        ).call("猫")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq([topic_2.id])
    end

    it "fuses, adds metadata to, and assigns request-owned source references" do
      SiteSetting.tagging_enabled = true
      parent_category = Fabricate(:category)
      category.update!(parent_category:)
      tag = Fabricate(:tag, name: "guide")
      topic_2.tags << tag
      PostActionCreator.like(user, post_2)
      lexical = [source(post_1), source(post_2)]
      semantic = [source(post_2), source(post_3)]

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { lexical },
          semantic_retriever: ->(_query) { semantic },
        ).call("猫")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [topic_2.id, topic_1.id, topic_3.id],
      )
      expect(result.candidates.map { |candidate| candidate.fetch("source_ref") }).to eq(
        %w[source_1 source_2 source_3],
      )
      expect(result.candidates.map { |candidate| candidate.fetch("category") }).to eq(
        3.times.map { "#{parent_category.name} > #{category.name}" },
      )
      expect(result.candidates.first).to include(
        "title" => topic_2.title,
        "url" => post_2.relative_url,
        "username" => post_2.user.username,
        "excerpt" => post_2.raw,
        "created" => post_2.created_at,
        "likes" => 1,
        "topic_views" => topic_2.views,
        "topic_likes" => topic_2.reload.like_count,
        "topic_replies" => topic_2.posts_count - 1,
        "tags" => tag.name,
        "name" => post_2.user.name,
        "avatar_template" => post_2.user.avatar_template,
        "author_is_staff" => true,
        "is_topic_op" => true,
      )
    end

    it "keeps distinct matched posts as passages when retrieval methods find the same topic" do
      matching_reply = Fabricate(:post, topic: topic_2, raw: "A later matching answer")

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(matching_reply)] },
          semantic_retriever: ->(_query) { [source(post_2)] },
        ).call("matching answer")

      expect(result.candidates.first.fetch("passages")).to eq(
        [
          {
            "post_id" => matching_reply.id,
            "post_number" => matching_reply.post_number,
            "url" => matching_reply.relative_url,
            "excerpt" => matching_reply.raw,
            "post_updated_at" => matching_reply.updated_at.iso8601(6),
          },
          {
            "post_id" => post_2.id,
            "post_number" => post_2.post_number,
            "url" => post_2.relative_url,
            "excerpt" => post_2.raw,
            "post_updated_at" => post_2.updated_at.iso8601(6),
          },
        ],
      )
    end

    it "uses keyword and semantic retrieval for personal messages the user can see" do
      personal_message = Fabricate(:private_message_post, recipient: user, raw: "Anime plans")
      lexical_retriever = instance_spy(Proc, call: [source(personal_message)])
      semantic_retriever = instance_spy(Proc, call: [source(personal_message)])

      result =
        described_class.new(user:, lexical_retriever:, semantic_retriever:).call(
          "Which PMs discuss anime?",
          keyword_query: "anime in:messages",
          semantic_query: "private conversations about anime",
        )

      expect(lexical_retriever).to have_received(:call).with("anime in:messages")
      expect(semantic_retriever).to have_received(:call).with("private conversations about anime")
      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [personal_message.topic_id],
      )
    end

    it "uses only keyword retrieval when a personal-message query has an ordering operator" do
      personal_message = Fabricate(:private_message_post, recipient: user, raw: "Anime plans")
      semantic_retriever = instance_spy(Proc, call: [source(post_2)])

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(personal_message)] },
          semantic_retriever:,
        ).call(
          "My most viewed anime PM",
          keyword_query: "anime in:messages order:views",
          semantic_query: "",
        )

      expect(semantic_retriever).not_to have_received(:call)
      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [personal_message.topic_id],
      )
    end

    it "preserves a personal-message user filter without semantic broadening" do
      matching_message = Fabricate(:private_message_post, recipient: user, raw: "Anime plans")
      unrelated_message =
        Fabricate(:private_message_post, recipient: user, raw: "Unrelated private plans")
      query = "anime personal_messages:#{user.username}"

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(matching_message)] },
          semantic_retriever: ->(_query) { [source(unrelated_message)] },
        ).call(query, keyword_query: query, semantic_query: "private conversations about anime")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [matching_message.topic_id],
      )
    end

    it "does not broaden explicit search filters through semantic retrieval" do
      lexical_retriever = instance_spy(Proc, call: [source(post_1)])
      semantic_retriever = instance_spy(Proc, call: [source(post_2)])

      result =
        described_class.new(user:, lexical_retriever:, semantic_retriever:).call(
          "猫 category:#{category.slug}",
          keyword_query: "rewritten query without filter",
          semantic_query: "rewritten semantic query",
        )

      expect(lexical_retriever).to have_received(:call).with("猫 category:#{category.slug}")
      expect(semantic_retriever).not_to have_received(:call)
      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq([topic_1.id])
    end

    it "excludes deleted posts and topics before synthesis" do
      candidates = [source(post_1), source(post_2), source(post_3)]
      post_2.update!(deleted_at: Time.zone.now)
      topic_3.update!(deleted_at: Time.zone.now)

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { candidates },
          semantic_retriever: ->(_query) { [] },
        ).call("useful answers")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq([topic_1.id])
    end
  end

  describe "#call with external sources" do
    def external_source(name: "Help center", &search)
      Struct
        .new(:name, :search) do
          def call(**queries) = search.call(**queries)
          def record_outcome(_outcome) = nil
        end
        .new(name, search)
    end

    def external_result(title, url)
      { "kind" => "external", "source_name" => "Help center", "title" => title, "url" => url }
    end

    it "fuses external results with the forum's and passes them the prepared queries" do
      received = nil
      help_center =
        external_source do |**queries|
          received = queries
          [external_result("Reset guide", "https://kb.example.com/reset")]
        end

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1)] },
          semantic_retriever: ->(_query) { [] },
          external_sources: [help_center],
        ).call(
          "how do I reset my password",
          keyword_query: "reset password",
          semantic_query: "How can I reset a forgotten password?",
          locale: "en",
        )

      expect(received).to eq(
        query: "how do I reset my password",
        keyword_query: "reset password",
        semantic_query: "How can I reset a forgotten password?",
        locale: "en",
      )
      expect(result.candidates.map { |candidate| candidate.values_at("url", "source_ref") }).to eq(
        [[post_1.relative_url, "source_1"], %w[https://kb.example.com/reset source_2]],
      )
    end

    it "keeps the other results when an external source fails or runs out of time" do
      failing = external_source(name: "Broken") { |**| raise "down" }
      slow =
        external_source(name: "Slow") do |**|
          sleep 2
          [external_result("Late", "https://kb.example.com/late")]
        end
      working = external_source { |**| [external_result("Docs", "https://kb.example.com/docs")] }

      SiteSetting.ai_ask_ai_external_sources_timeout = 1

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [] },
          semantic_retriever: ->(_query) { [] },
          external_sources: [failing, slow, working],
        ).call("docs")

      expect(result.candidates.pluck("url")).to eq(["https://kb.example.com/docs"])
    end

    it "answers from external sources when the forum's retrieval fails" do
      help_center =
        external_source { |**| [external_result("Docs", "https://kb.example.com/docs")] }
      failing_forum = ->(_query) { raise "embeddings unavailable" }

      result =
        described_class.new(
          user:,
          lexical_retriever: failing_forum,
          semantic_retriever: failing_forum,
          external_sources: [help_center],
        ).call("docs")

      expect(result.candidates.pluck("url")).to eq(["https://kb.example.com/docs"])
      expect {
        described_class.new(
          user:,
          lexical_retriever: failing_forum,
          semantic_retriever: failing_forum,
          external_sources: [external_source { |**| [] }],
        ).call("docs")
      }.to raise_error("embeddings unavailable")
    end

    it "records how each source's search ended" do
      SiteSetting.ai_ask_ai_external_sources_timeout = 1
      scripts = {
        "Fast" => "function invoke() { return []; }",
        "Slow" => "function invoke() { sleep(3000); return []; }",
        "Broken" => "function invoke() { throw new Error('down'); }",
      }
      tools = scripts.map { |name, script| Fabricate(:ai_tool, name:, script:) }

      described_class.new(
        user:,
        lexical_retriever: ->(_query) { [] },
        semantic_retriever: ->(_query) { [] },
        external_sources:
          tools.map { |tool| DiscourseAi::Discoveries::ExternalSource.new(tool, user:) },
      ).call("docs")

      outcomes =
        tools.to_h do |tool|
          counts = DiscourseAi::Discoveries::ExternalSource.outcome_counts(tool.id, hours: 1)
          [tool.name, counts.select { |_outcome, count| count > 0 }.keys]
        end
      expect(outcomes).to eq(
        "Fast" => %w[succeeded],
        "Slow" => %w[timed_out],
        "Broken" => %w[failed],
      )
    end

    it "skips external sources once too many are still running" do
      ai_tool = Fabricate(:ai_tool, script: "function invoke() { return []; }")
      source = DiscourseAi::Discoveries::ExternalSource.new(ai_tool, user:)

      stub_const(DiscourseAi::Discoveries::ExternalSource, :MAX_IN_FLIGHT, 0) do
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1)] },
          semantic_retriever: ->(_query) { [] },
          external_sources: [source],
        ).call("docs")
      end

      expect(
        DiscourseAi::Discoveries::ExternalSource.outcome_counts(ai_tool.id, hours: 1),
      ).to include("busy" => 1, "succeeded" => 0)
    end

    it "searches only external sources when the forum's searches are disabled" do
      SiteSetting.ai_ask_ai_keyword_search_enabled = false
      SiteSetting.ai_ask_ai_semantic_search_enabled = false
      lexical_retriever = instance_spy(Proc, call: [source(post_1)])
      help_center =
        external_source { |**| [external_result("Docs", "https://kb.example.com/docs")] }

      result =
        described_class.new(user:, lexical_retriever:, external_sources: [help_center]).call(
          "docs",
          scope_filter: "category:#{category.id}",
        )

      expect(result.candidates.pluck("url")).to eq(["https://kb.example.com/docs"])
      expect(result.scope_fallback).to be_nil
      expect(lexical_retriever).not_to have_received(:call)
    end

    it "searches the whole forum when only external sources match inside the scope" do
      lexical_retriever = ->(query) { query.include?("category:") ? [] : [source(post_1)] }
      help_center =
        external_source { |**| [external_result("Docs", "https://kb.example.com/docs")] }

      result =
        described_class.new(
          user:,
          lexical_retriever:,
          semantic_retriever: ->(_query) { [] },
          external_sources: [help_center],
        ).call("docs", scope_filter: "category:#{category.id}")

      expect(result.candidates.pluck("url")).to contain_exactly(
        post_1.relative_url,
        "https://kb.example.com/docs",
      )
      expect(result.scope_fallback).to eq(true)
    end
  end

  describe "#call with site-set search limits" do
    it "adds the category and age limits to both retrievals and keeps them when widening a scope" do
      freeze_time Time.utc(2026, 10, 23)
      SiteSetting.ai_ask_ai_search_categories = category.id.to_s
      SiteSetting.ai_ask_ai_search_max_age_days = 30
      lexical_retriever = instance_spy(Proc, call: [])
      semantic_retriever = instance_spy(Proc, call: [])

      described_class.new(user:, lexical_retriever:, semantic_retriever:).call(
        "reset password",
        scope_filter: "tag:guides",
      )

      limits = "after:2026-09-23 categories:#{category.id}"
      expect(lexical_retriever).to have_received(:call).with("reset password tag:guides #{limits}")
      expect(lexical_retriever).to have_received(:call).with("reset password #{limits}")
      expect(semantic_retriever).to have_received(:call).with("reset password #{limits}")
    end

    it "keeps only the age limit for personal message searches" do
      freeze_time Time.utc(2026, 10, 23)
      SiteSetting.ai_ask_ai_search_categories = category.id.to_s
      SiteSetting.ai_ask_ai_search_max_age_days = 30
      lexical_retriever = instance_spy(Proc, call: [])

      described_class.new(user:, lexical_retriever:, semantic_retriever: ->(_query) { [] }).call(
        "widget in:messages",
      )

      expect(lexical_retriever).to have_received(:call).with("widget in:messages after:2026-09-23")
    end
  end

  describe "#sources_for" do
    it "resolves known source references in the model's order, dropping the rest" do
      retrieval =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1), source(post_2)] },
          semantic_retriever: ->(_query) { [] },
        )
      result = retrieval.call("useful answers")

      sources =
        retrieval.sources_for(
          result,
          ["source_2", "unknown", "source_2", nil, { "ref" => 1 }, "source_1"],
          limit: 6,
        )

      expect(sources.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [topic_2.id, topic_1.id],
      )
      expect(retrieval.sources_for(result, %w[source_2 source_1], limit: 1).length).to eq(1)
      expect(retrieval.sources_for(result, nil, limit: 6)).to eq([])
    end
  end

  describe "indexed retrieval" do
    before { SearchIndexer.enable }
    after { SearchIndexer.disable }

    it "finds keyword matches without requesting embeddings when embeddings are disabled" do
      SiteSetting.ai_embeddings_enabled = false
      embedding_request = stub_request(:post, embedding_definition.url).to_return(status: 500)
      SearchIndexer.index(post_1, force: true)

      result = described_class.new(user:).call("useful")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq([topic_1.id])
      expect(embedding_request).not_to have_been_requested
    end

    it "preserves category filters, includes subcategories, and excludes inaccessible topics" do
      child_category = Fabricate(:category, parent_category: category)
      token = "discoveryneedle#{SecureRandom.hex(6)}"
      parent_post = Fabricate(:post, topic: Fabricate(:topic, category:), raw: token)
      child_post = Fabricate(:post, topic: Fabricate(:topic, category: child_category), raw: token)
      hidden_post = Fabricate(:post, topic: private_topic, raw: token)
      [parent_post, child_post, hidden_post].each { |post| SearchIndexer.index(post, force: true) }

      retrieval = described_class.new(user:, semantic_retriever: ->(_query) { [] })
      result = retrieval.call("#{token} ##{category.slug}")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to contain_exactly(
        parent_post.topic_id,
        child_post.topic_id,
      )
    end

    it "excludes personal messages from a regular keyword search" do
      SiteSetting.ai_embeddings_enabled = false
      token = "regularneedle#{SecureRandom.hex(6)}"
      public_post = Fabricate(:post, topic: Fabricate(:topic, category:), raw: token)
      personal_message = Fabricate(:private_message_post, recipient: user, raw: token)
      [public_post, personal_message].each { |post| SearchIndexer.index(post, force: true) }

      result = described_class.new(user:).call(token)

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [public_post.topic_id],
      )
    end

    it "finds only personal messages the user can see without embeddings" do
      SiteSetting.ai_embeddings_enabled = false
      embedding_request = stub_request(:post, embedding_definition.url).to_return(status: 500)
      token = "privateneedle#{SecureRandom.hex(6)}"
      personal_message = Fabricate(:private_message_post, recipient: user, raw: token)
      inaccessible_message = Fabricate(:private_message_post, raw: token)
      [personal_message, inaccessible_message].each do |post|
        SearchIndexer.index(post, force: true)
      end

      result = described_class.new(user:).call("#{token} in:messages")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [personal_message.topic_id],
      )
      expect(embedding_request).not_to have_been_requested
    end
  end
end
