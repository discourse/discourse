# frozen_string_literal: true

RSpec.describe Jobs::RemoveOrphanedEmbeddings do
  subject(:job) { described_class.new }

  before { enable_current_plugin }

  describe "#execute" do
    fab!(:embedding_definition)
    fab!(:embedding_definition_2) { Fabricate(:embedding_definition) }
    fab!(:topic)
    fab!(:post)

    before do
      DiscourseAi::Embeddings::Schema.prepare_search_indexes(embedding_definition)
      DiscourseAi::Embeddings::Schema.prepare_search_indexes(embedding_definition_2)

      # Seed embeddings. One of each def x target classes.
      [embedding_definition, embedding_definition_2].each do |edef|
        SiteSetting.ai_embeddings_selected_model = edef.id

        [topic, post].each do |target|
          schema = DiscourseAi::Embeddings::Schema.for(target.class)
          schema.store(target, [1] * edef.dimensions, "test")
        end
      end

      embedding_definition.destroy!
    end

    def find_all_embeddings_of(target, table, target_column)
      DB.query_single("SELECT model_id FROM #{table} WHERE #{target_column} = #{target.id}")
    end

    it "delete embeddings without an existing embedding definition" do
      expect(find_all_embeddings_of(post, "ai_posts_embeddings", "post_id")).to contain_exactly(
        embedding_definition.id,
        embedding_definition_2.id,
      )
      expect(find_all_embeddings_of(topic, "ai_topics_embeddings", "topic_id")).to contain_exactly(
        embedding_definition.id,
        embedding_definition_2.id,
      )

      job.execute({})

      expect(find_all_embeddings_of(topic, "ai_topics_embeddings", "topic_id")).to contain_exactly(
        embedding_definition_2.id,
      )
      expect(find_all_embeddings_of(post, "ai_posts_embeddings", "post_id")).to contain_exactly(
        embedding_definition_2.id,
      )
    end

    it "deletes orphaned indexes" do
      expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_definition)).to eq(true)
      expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_definition_2)).to eq(true)

      job.execute({})

      index_names =
        DiscourseAi::Embeddings::Schema::EMBEDDING_TARGETS.map do |t|
          "ai_#{t}_embeddings_#{embedding_definition.id}_1_search_bit"
        end
      indexnames =
        DB.query_single(
          "SELECT indexname FROM pg_indexes WHERE indexname IN (:names)",
          names: index_names,
        )

      expect(indexnames).to be_empty
      expect(DiscourseAi::Embeddings::Schema.correctly_indexed?(embedding_definition_2)).to eq(true)
    end
  end
end
