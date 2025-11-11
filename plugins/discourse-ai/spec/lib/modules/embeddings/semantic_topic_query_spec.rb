# frozen_string_literal: true

describe DiscourseAi::Embeddings::EntryPoint do
  fab!(:user)

  before { enable_current_plugin }

  describe "SemanticTopicQuery extension" do
    describe "#list_semantic_related_topics" do
      subject(:topic_query) { DiscourseAi::Embeddings::SemanticTopicQuery.new(user) }

      fab!(:target, :topic)

      fab!(:vector_def, :cloudflare_embedding_def)

      before do
        SiteSetting.ai_embeddings_enabled = true
        SiteSetting.ai_embeddings_selected_model = vector_def.id
      end

      # The Distance gap to target increases for each element of topics.
      def seed_embeddings(topics)
        schema = DiscourseAi::Embeddings::Schema.for(Topic)
        base_value = 1

        schema.store(target, [base_value] * 1024, "disgest")

        topics.each do |t|
          base_value -= 0.01
          schema.store(t, [base_value] * 1024, "digest")
        end
      end

      after { DiscourseAi::Embeddings::SemanticRelated.clear_cache_for(target) }

      context "when the semantic search returns an unlisted topic" do
        fab!(:unlisted_topic) { Fabricate(:topic, visible: false) }

        before { seed_embeddings([unlisted_topic]) }

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to be_empty
        end
      end

      context "when the semantic search returns a private topic" do
        fab!(:private_topic, :private_message_topic)

        before { seed_embeddings([private_topic]) }

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to be_empty
        end
      end

      context "when the semantic search returns a topic from a restricted category" do
        fab!(:group)
        fab!(:category) { Fabricate(:private_category, group: group) }
        fab!(:secured_category_topic) { Fabricate(:topic, category: category) }

        before { seed_embeddings([secured_category_topic]) }

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to be_empty
        end

        it "doesn't filter it out if the user has access to the category" do
          group.add(user)

          expect(topic_query.list_semantic_related_topics(target).topics).to contain_exactly(
            secured_category_topic,
          )
        end
      end

      context "when the semantic search returns a closed topic and we explicitly exclude them" do
        fab!(:closed_topic) { Fabricate(:topic, closed: true) }

        before do
          SiteSetting.ai_embeddings_semantic_related_include_closed_topics = false
          seed_embeddings([closed_topic])
        end

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to be_empty
        end
      end

      context "when the semantic search returns a muted topic" do
        it "filters it out" do
          category = Fabricate(:category_with_definition)
          topic = Fabricate(:topic, category: category)
          CategoryUser.create!(
            user_id: user.id,
            category_id: category.id,
            notification_level: CategoryUser.notification_levels[:muted],
          )
          seed_embeddings([topic])
          expect(topic_query.list_semantic_related_topics(target).topics).not_to include(topic)
        end
      end

      context "when the semantic search returns public topics" do
        fab!(:normal_topic_1, :topic)
        fab!(:normal_topic_2, :topic)
        fab!(:normal_topic_3, :topic)
        fab!(:closed_topic) { Fabricate(:topic, closed: true) }

        before { seed_embeddings([closed_topic, normal_topic_1, normal_topic_2, normal_topic_3]) }

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to eq(
            [closed_topic, normal_topic_1, normal_topic_2, normal_topic_3],
          )
        end

        it "returns the plugin limit for the number of results" do
          SiteSetting.ai_embeddings_semantic_related_topics = 2

          expect(topic_query.list_semantic_related_topics(target).topics).to contain_exactly(
            closed_topic,
            normal_topic_1,
          )
        end
      end

      context "with semantic_related_topics_query modifier registered" do
        fab!(:included_topic, :topic)
        fab!(:excluded_topic, :topic)

        before { seed_embeddings([included_topic, excluded_topic]) }

        let(:modifier_block) { Proc.new { |query| query.where.not(id: excluded_topic.id) } }

        it "Allows modifications to default results (excluding a topic in this case)" do
          plugin_instance = Plugin::Instance.new
          plugin_instance.register_modifier(:semantic_related_topics_query, &modifier_block)

          expect(topic_query.list_semantic_related_topics(target).topics).to eq([included_topic])
        ensure
          DiscoursePluginRegistry.unregister_modifier(
            plugin_instance,
            :semantic_related_topics_query,
            &modifier_block
          )
        end
      end
    end
  end
end
