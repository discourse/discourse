# frozen_string_literal: true

describe DiscourseAi::Discoveries::Retrieval do
  fab!(:user)
  fab!(:category)
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:topic_1) { Fabricate(:topic, category:) }
  fab!(:topic_2) { Fabricate(:topic, category:) }
  fab!(:topic_3) { Fabricate(:topic, category:) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:post_1) { Fabricate(:post, topic: topic_1, raw: "First useful answer") }
  fab!(:post_2) { Fabricate(:post, topic: topic_2, raw: "Second useful answer") }
  fab!(:post_3) { Fabricate(:post, topic: topic_3, raw: "Third useful answer") }
  fab!(:private_post) { Fabricate(:post, topic: private_topic, raw: "Private answer") }

  def source(post, excerpt: post.raw)
    {
      "topic_id" => post.topic_id,
      "post_id" => post.id,
      "title" => post.topic.title,
      "url" => post.relative_url,
      "excerpt" => excerpt,
    }
  end

  describe "#call" do
    it "fuses, permission-checks, reranks, and assigns request-owned source references" do
      lexical = [source(post_1), source(post_2), source(private_post)]
      semantic = [source(post_2), source(post_3), source(private_post)]
      reranker =
        lambda do |_query, candidates|
          expect(candidates.length).to eq(3)
          [{ index: 2, score: 0.9 }, { index: 1, score: 0.8 }, { index: 0, score: 0.7 }]
        end

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { lexical },
          semantic_retriever: ->(_query) { semantic },
          reranker:,
        ).call("猫")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [topic_3.id, topic_1.id, topic_2.id],
      )
      expect(result.candidates.map { |candidate| candidate.fetch("source_ref") }).to eq(
        %w[source_1 source_2 source_3],
      )
      expect(result.candidates.map { |candidate| candidate.fetch("category") }).to eq(
        [category.name, category.name, category.name],
      )
    end

    it "returns no candidates for a personal-message search" do
      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1)] },
          semantic_retriever: ->(_query) { [source(post_1)] },
          reranker: ->(_query, _candidates) { [{ index: 0, score: 1.0 }] },
        ).call("cats in:messages")

      expect(result.candidates).to eq([])
    end

    it "does not broaden explicit search filters through semantic retrieval" do
      semantic_retriever = instance_spy(Proc, call: [source(post_2)])

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1)] },
          semantic_retriever:,
          reranker: ->(_query, _candidates) { [{ index: 0, score: 1.0 }] },
        ).call("猫 category:#{category.slug}")

      expect(semantic_retriever).not_to have_received(:call)
      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq([topic_1.id])
    end

    it "excludes deleted posts and topics before reranking" do
      candidates = [source(post_1), source(post_2), source(post_3)]
      post_2.update!(deleted_at: Time.zone.now)
      topic_3.update!(deleted_at: Time.zone.now)

      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { candidates },
          semantic_retriever: ->(_query) { [] },
          reranker: ->(_query, _candidates) { [{ index: 0, score: 1.0 }] },
        ).call("useful answers")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq([topic_1.id])
    end

    it "ignores duplicate candidate indexes from the reranker" do
      result =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1), source(post_2)] },
          semantic_retriever: ->(_query) { [] },
          reranker: ->(_query, _candidates) do
            [{ index: 0, score: 1.0 }, { index: 0, score: 0.9 }, { index: 1, score: 0.8 }]
          end,
        ).call("useful answers")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to eq(
        [topic_1.id, topic_2.id],
      )
    end
  end

  describe "#validated_sources" do
    it "accepts up to six known source references and rechecks access before publication" do
      retrieval =
        described_class.new(
          user:,
          lexical_retriever: ->(_query) { [source(post_1), source(post_2)] },
          semantic_retriever: ->(_query) { [] },
          reranker: ->(_query, _candidates) do
            [{ index: 0, score: 1.0 }, { index: 1, score: 0.9 }]
          end,
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
          reranker: ->(_query, _candidates) { [{ index: 0, score: 1.0 }] },
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
          reranker: ->(_query, _candidates) { [{ index: 0, score: 1.0 }] },
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

      retrieval =
        described_class.new(
          user:,
          semantic_retriever: ->(_query) { [] },
          reranker: ->(_query, candidates) do
            candidates.each_index.map { |index| { index:, score: 1.0 - index.fdiv(100) } }
          end,
        )
      result = retrieval.call("#{token} ##{category.slug}")

      expect(result.candidates.map { |candidate| candidate.fetch("topic_id") }).to contain_exactly(
        parent_post.topic_id,
        child_post.topic_id,
      )
    end
  end
end
