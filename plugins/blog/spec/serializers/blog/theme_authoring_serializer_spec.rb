# frozen_string_literal: true

RSpec.describe Blog::ThemeAuthoringSerializer do
  subject(:json) do
    described_class.new(publications, root: false, variables:).as_json.deep_stringify_keys
  end

  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:first_post) { Fabricate(:post, topic:) }
  fab!(:publication) do
    Blog::Publication.create!(
      topic:,
      discussion_topic: topic,
      path: "/sample",
      published: true,
      published_at: 1.day.ago,
    )
  end

  let(:publications) { [publication] }
  let(:variables) { { "site" => { "title" => "Spec blog" } } }

  before { enable_blog!(category:) }

  it "lists each sample article by id and title" do
    expect(json["articles"]).to eq(
      [{ "id" => publication.id, "title" => publication.article.title }],
    )
  end

  it "provides every built-in template keyed by its theme field" do
    expect(json["templates"].keys).to eq(Blog::BlogTheme::TEMPLATE_FIELDS)
    expect(json["templates"]["template_layout"]).to eq(Blog::TemplateRenderer.builtin("layout"))
  end

  it "passes the template variables through" do
    expect(json["variables"]).to eq(variables)
  end
end
