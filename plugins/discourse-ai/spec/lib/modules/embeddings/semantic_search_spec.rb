# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::SemanticSearch do
  fab!(:post)
  fab!(:user)

  let(:query) { "test_query" }
  let(:subject) { described_class.new(Guardian.new(user)) }

  fab!(:vector_def) { Fabricate(:embedding_definition) }

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    assign_fake_provider_to(:ai_embeddings_semantic_search_hyde_model)
  end

  describe "#search_for_topics" do
    let(:hypothetical_post) { "This is an hypothetical post generated from the keyword test_query" }
    let(:hyde_embedding) { [0.049382] * vector_def.dimensions }

    before { EmbeddingsGenerationStubs.hugging_face_service(hypothetical_post, hyde_embedding) }

    after { described_class.clear_cache_for(query) }

    def insert_candidate(candidate)
      DiscourseAi::Embeddings::Schema.for(Topic).store(candidate, hyde_embedding, "digest")
    end

    def trigger_search(query)
      DiscourseAi::Completions::Llm.with_prepared_responses([hypothetical_post]) do
        subject.search_for_topics(query)
      end
    end

    it "returns the first post of a topic included in the asymmetric search results" do
      insert_candidate(post.topic)

      posts = trigger_search(query)

      expect(posts).to contain_exactly(post)
    end

    describe "applies different scopes to the candidates" do
      context "when the topic is not visible" do
        it "returns an empty list" do
          post.topic.update!(visible: false)
          insert_candidate(post.topic)

          posts = trigger_search(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not public" do
        it "returns an empty list" do
          pm_post = Fabricate(:private_message_post)
          insert_candidate(pm_post.topic)

          posts = trigger_search(query)

          expect(posts).to be_empty
        end
      end

      context "when the post type is not visible" do
        it "returns an empty list" do
          post.update!(post_type: Post.types[:whisper])
          insert_candidate(post.topic)

          posts = trigger_search(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not the first post in the topic" do
        it "returns an empty list" do
          reply = Fabricate(:reply)
          reply.topic.first_post.trash!
          insert_candidate(reply.topic)

          posts = trigger_search(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not a candidate" do
        it "doesn't include it in the results" do
          post_2 = Fabricate(:post)
          insert_candidate(post.topic)

          posts = trigger_search(query)

          expect(posts).not_to include(post_2)
        end
      end

      context "when the post belongs to a secured category" do
        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group: group) }

        before do
          post.topic.update!(category: private_category)
          insert_candidate(post.topic)
        end

        it "returns an empty list" do
          posts = trigger_search(query)

          expect(posts).to be_empty
        end

        it "returns the results if the user has access to the category" do
          group.add(user)

          posts = trigger_search(query)

          expect(posts).to contain_exactly(post)
        end

        context "while searching as anon" do
          it "returns an empty list" do
            posts =
              DiscourseAi::Completions::Llm.with_prepared_responses([hypothetical_post]) do
                described_class.new(Guardian.new(nil)).search_for_topics(query)
              end

            expect(posts).to be_empty
          end
        end
      end
    end
  end
end
