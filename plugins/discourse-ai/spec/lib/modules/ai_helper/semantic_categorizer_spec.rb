# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::SemanticCategorizer do
  fab!(:vector_def, :embedding_definition)
  fab!(:user)
  fab!(:muted_category, :category)
  fab!(:category_mute) do
    CategoryUser.create!(
      user: user,
      category: muted_category,
      notification_level: CategoryUser.notification_levels[:muted],
    )
  end
  fab!(:muted_topic) { Fabricate(:topic, category: muted_category) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  let(:vector) { DiscourseAi::Embeddings::Vector.instance }
  let(:categorizer) { DiscourseAi::AiHelper::SemanticCategorizer.new(user, { text: "hello" }) }
  let(:expected_embedding) { [0.0038493] * vector.vdef.dimensions }

  before do
    enable_current_plugin

    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true

    WebMock.stub_request(:post, vector_def.url).to_return(
      status: 200,
      body: JSON.dump([expected_embedding]),
    )

    vector.generate_representation_from(topic)
    vector.generate_representation_from(muted_topic)
  end

  it "respects user muted categories when making suggestions" do
    category_ids = categorizer.categories.map { |c| c[:id] }
    expect(category_ids).not_to include(muted_category.id)
    expect(category_ids).to include(category.id)
  end

  it "does not mutate vdef.pg_function when computing category scores" do
    inner_vector = categorizer.instance_variable_get(:@vector)
    expect(inner_vector.vdef.pg_function).to eq("<=>")
    categorizer.categories
    expect(inner_vector.vdef.pg_function).to eq("<=>")
  end

  it "does not mutate vdef.pg_function when computing tag scores" do
    tag = Fabricate(:tag)
    Fabricate(:topic_tag, topic: topic, tag: tag)

    inner_vector = categorizer.instance_variable_get(:@vector)
    expect(inner_vector.vdef.pg_function).to eq("<=>")
    categorizer.tags
    expect(inner_vector.vdef.pg_function).to eq("<=>")
  end

  def seed_candidate_tagged_with(tag)
    topic = Fabricate(:topic)
    Fabricate(:topic_tag, topic:, tag:)
    vector.generate_representation_from(topic)
  end

  describe "category tag restrictions" do
    fab!(:restricted_tag, :tag)
    fab!(:allowed_tag, :tag)

    fab!(:restricted_category) { Fabricate(:category, allowed_tags: [allowed_tag.name]) }

    before do
      seed_candidate_tagged_with(restricted_tag)
      seed_candidate_tagged_with(allowed_tag)
    end

    it "does not suggest a tag the selected category disallows" do
      suggested =
        described_class
          .new(user, { text: "hello", category: restricted_category })
          .tags
          .map { |t| t[:name] }

      expect(suggested).to include(allowed_tag.name)
      expect(suggested).not_to include(restricted_tag.name)
    end

    it "suggests the tag in a category that allows it" do
      permissive_category = Fabricate(:category, allow_global_tags: true)

      suggested =
        described_class
          .new(user, { text: "hello", category: permissive_category })
          .tags
          .map { |t| t[:name] }

      expect(suggested).to include(restricted_tag.name)
    end
  end

  describe "one tag per group restrictions" do
    fab!(:selected_tag, :tag)
    fab!(:sibling_tag, :tag)
    fab!(:tag_group) do
      Fabricate(:tag_group, tags: [selected_tag, sibling_tag], one_per_topic: true)
    end

    before { seed_candidate_tagged_with(sibling_tag) }

    it "excludes a one-per-topic group sibling once a member is selected" do
      without_selection = described_class.new(user, { text: "hello" }).tags.map { |t| t[:name] }
      expect(without_selection).to include(sibling_tag.name)

      with_selection =
        described_class
          .new(user, { text: "hello", selected_tag_ids: [selected_tag.id] })
          .tags
          .map { |t| t[:name] }
      expect(with_selection).not_to include(sibling_tag.name)
    end
  end
end
