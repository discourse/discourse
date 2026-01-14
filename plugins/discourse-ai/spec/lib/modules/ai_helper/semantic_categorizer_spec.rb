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
end
