#frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::Search do
  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:progress_blk) { Proc.new {} }

  fab!(:admin)
  fab!(:parent_category) { Fabricate(:category, name: "animals") }
  fab!(:category) { Fabricate(:category, parent_category: parent_category, name: "amazing-cat") }
  fab!(:tag_funny) { Fabricate(:tag, name: "funny") }
  fab!(:tag_sad) { Fabricate(:tag, name: "sad") }
  fab!(:tag_hidden) { Fabricate(:tag, name: "hidden") }
  fab!(:staff_tag_group) do
    tag_group = Fabricate.build(:tag_group, name: "Staff only", tag_names: ["hidden"])

    tag_group.permissions = [
      [Group::AUTO_GROUPS[:staff], TagGroupPermission.permission_types[:full]],
    ]
    tag_group.save!
    tag_group
  end
  fab!(:topic_with_tags) do
    Fabricate(:topic, category: category, tags: [tag_funny, tag_sad, tag_hidden])
  end

  fab!(:user)
  fab!(:group)
  fab!(:private_category) do
    c = Fabricate(:category_with_definition)
    c.set_permissions(group => :readonly)
    c.save
    c
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#invoke" do
    it "can retrieve options from persona correctly" do
      persona_options = {
        "base_query" => "#funny",
        "search_private" => "true",
        "max_results" => "10",
      }

      search_post = Fabricate(:post, topic: topic_with_tags)
      private_search_post = Fabricate(:post, topic: Fabricate(:topic, category: private_category))
      private_search_post.topic.tags = [tag_funny]
      private_search_post.topic.save!

      _bot_post = Fabricate(:post)

      search =
        described_class.new(
          { order: "latest" },
          persona_options: persona_options,
          bot_user: bot_user,
          llm: llm,
          context: DiscourseAi::Personas::BotContext.new(user: user),
        )

      expect(search.options[:base_query]).to eq("#funny")
      expect(search.options[:search_private]).to eq(true)
      expect(search.options[:max_results]).to eq(10)

      results = search.invoke(&progress_blk)
      expect(results[:rows].length).to eq(1)

      expect(search.last_query).to eq("#funny order:latest")

      GroupUser.create!(group: group, user: user)

      results = search.invoke(&progress_blk)
      expect(results[:rows].length).to eq(2)

      search_post.topic.tags = []
      search_post.topic.save!

      # no longer has the tag funny, but secure one does
      results = search.invoke(&progress_blk)
      expect(results[:rows].length).to eq(1)
    end

    it "can handle no results" do
      _post1 = Fabricate(:post, topic: topic_with_tags)
      search =
        described_class.new(
          { search_query: "ABDDCDCEDGDG", order: "fake" },
          bot_user: bot_user,
          llm: llm,
        )

      results = search.invoke(&progress_blk)

      expect(results[:args]).to eq({ search_query: "ABDDCDCEDGDG", order: "fake", max_results: 60 })
      expect(results[:rows]).to eq([])
    end

    describe "semantic search" do
      let(:query) { "this is an expanded search" }

      after do
        DiscourseAi::Embeddings::SemanticSearch.clear_cache_for(query)
        SiteSetting.ai_embeddings_semantic_search_use_hyde = false
      end

      it "supports semantic search when enabled" do
        assign_fake_provider_to(:ai_default_llm_model)
        SiteSetting.ai_embeddings_semantic_search_use_hyde = true

        vector_def = Fabricate(:embedding_definition)
        SiteSetting.ai_embeddings_selected_model = vector_def.id
        SiteSetting.ai_embeddings_enabled = true
        SiteSetting.ai_embeddings_semantic_search_enabled = true

        hyde_embedding = [0.049382] * vector_def.dimensions

        EmbeddingsGenerationStubs.hugging_face_service(query, hyde_embedding)

        post1 = Fabricate(:post, topic: topic_with_tags)
        search =
          described_class.new(
            { search_query: "hello world, sam", status: "public" },
            llm: llm,
            bot_user: bot_user,
          )

        DiscourseAi::Embeddings::Schema.for(Topic).store(post1.topic, hyde_embedding, "digest")

        results =
          DiscourseAi::Completions::Llm.with_prepared_responses([query]) do
            search.invoke(&progress_blk)
          end

        expect(results[:args]).to eq(
          { max_results: 60, search_query: "hello world, sam", status: "public" },
        )
        expect(results[:rows].length).to eq(1)

        # it also works with no query
        search =
          described_class.new(
            { order: "likes", user: "sam", status: "public", search_query: "a" },
            llm: llm,
            bot_user: bot_user,
          )

        # results will be expanded by semantic search, but it will find nothing
        results =
          DiscourseAi::Completions::Llm.with_prepared_responses([query]) do
            search.invoke(&progress_blk)
          end

        expect(results[:rows].length).to eq(0)
      end
    end

    it "supports subfolder properly" do
      Discourse.stubs(:base_path).returns("/subfolder")

      post1 = Fabricate(:post, topic: topic_with_tags)

      search =
        described_class.new({ limit: 1, user: post1.user.username }, bot_user: bot_user, llm: llm)

      results = search.invoke(&progress_blk)
      expect(results[:rows].to_s).to include("/subfolder" + post1.url)
    end

    it "passes on all search params" do
      params =
        described_class.signature[:parameters]
          .map do |param|
            if param[:type] == "integer"
              [param[:name], 1]
            else
              [param[:name], "test"]
            end
          end
          .compact
          .to_h
          .symbolize_keys

      search = described_class.new(params, bot_user: bot_user, llm: llm)
      results = search.invoke(&progress_blk)

      expect(results[:args]).to eq(params)
    end

    it "returns rich topic information" do
      post1 = Fabricate(:post, like_count: 1, topic: topic_with_tags)
      search = described_class.new({ user: post1.user.username }, bot_user: bot_user, llm: llm)
      post1.topic.update!(views: 100, posts_count: 2, like_count: 10)

      results = search.invoke(&progress_blk)

      row = results[:rows].first
      category = row[results[:column_names].index("category")]

      expect(category).to eq("animals > amazing-cat")

      tags = row[results[:column_names].index("tags")]
      expect(tags).to eq("funny, sad")

      likes = row[results[:column_names].index("likes")]
      expect(likes).to eq(1)

      username = row[results[:column_names].index("username")]
      expect(username).to eq(post1.user.username)

      likes = row[results[:column_names].index("topic_likes")]
      expect(likes).to eq(10)

      views = row[results[:column_names].index("topic_views")]
      expect(views).to eq(100)

      replies = row[results[:column_names].index("topic_replies")]
      expect(replies).to eq(1)
    end
  end
end
