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
  fab!(:private_post) { Fabricate(:post, topic: private_topic, raw: "Private answer") }

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

    it "fuses, permission-checks, and assigns request-owned source references" do
      SiteSetting.tagging_enabled = true
      parent_category = Fabricate(:category)
      category.update!(parent_category:)
      tag = Fabricate(:tag, name: "guide")
      topic_2.tags << tag
      PostActionCreator.like(user, post_2)
      lexical = [source(post_1), source(post_2), source(private_post)]
      semantic = [source(post_2), source(post_3), source(private_post)]

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
      inaccessible_message = Fabricate(:private_message_post, raw: "Hidden anime plans")
      lexical_retriever =
        instance_spy(
          Proc,
          call: [source(personal_message), source(inaccessible_message), source(post_1)],
        )
      semantic_retriever =
        instance_spy(
          Proc,
          call: [source(personal_message), source(inaccessible_message), source(post_1)],
        )

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

    it "excludes personal messages from a regular search" do
      personal_message = Fabricate(:private_message_post, recipient: user, raw: "Anime plans")

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1), source(personal_message)] },
          semantic_retriever: ->(_query) { [] },
        ).call("anime")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq([topic_1.id])
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

  describe "#validated_sources" do
    it "accepts up to six known source references and rechecks access before publication" do
      retrieval =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1), source(post_2)] },
          semantic_retriever: ->(_query) { [] },
        )
      result = retrieval.call("useful answers")

      sources = retrieval.validated_sources(result, %w[source_2 source_1])
      expect(sources.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [topic_2.id, topic_1.id],
      )

      topic_2.update!(category: private_category)
      expect(retrieval.validated_sources(result, %w[source_2 source_1])).to eq([])
    end

    it "rejects duplicate, unknown, empty, or excessive source references" do
      retrieval =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1)] },
          semantic_retriever: ->(_query) { [] },
        )
      result = retrieval.call("useful answers")

      expect(retrieval.validated_sources(result, [])).to eq([])
      expect(retrieval.validated_sources(result, %w[source_1 source_1])).to eq([])
      expect(retrieval.validated_sources(result, %w[source_1 unknown])).to eq([])
      expect(retrieval.validated_sources(result, %w[a b c d e f g])).to eq([])
    end

    it "rejects a supporting source that changes after retrieval" do
      retrieval =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1)] },
          semantic_retriever: ->(_query) { [] },
        )
      result = retrieval.call("useful answers")

      post_1.update!(raw: "Changed after synthesis began")

      expect(retrieval.validated_sources(result, %w[source_1])).to eq([])
    end
  end

  describe "indexed retrieval" do
    before { SearchIndexer.enable }
    after { SearchIndexer.disable }

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

    it "finds only personal messages the user can see" do
      token = "privateneedle#{SecureRandom.hex(6)}"
      personal_message = Fabricate(:private_message_post, recipient: user, raw: token)
      inaccessible_message = Fabricate(:private_message_post, raw: token)
      [personal_message, inaccessible_message].each do |post|
        SearchIndexer.index(post, force: true)
      end

      result = described_class.new(user:).call("#{token} in:messages", semantic_query: "")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [personal_message.topic_id],
      )
    end
  end
end
