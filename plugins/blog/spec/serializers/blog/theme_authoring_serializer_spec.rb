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

  it "says when there's no standalone page to preview" do
    expect(json["has_page"]).to eq(false)
  end

  context "with a published standalone page" do
    before { publication.update!(page: true) }

    it "says a page can be previewed" do
      expect(json["has_page"]).to eq(true)
    end
  end

  context "when there are no published articles" do
    let(:publications) { [] }

    it "returns an empty articles list" do
      expect(json["articles"]).to eq([])
    end
  end

  it "provides every built-in template keyed by its theme field" do
    expect(json["templates"].keys).to eq(Blog::BlogTheme::TEMPLATE_FIELDS)
    expect(json["templates"]["template_layout"]).to eq(Blog::TemplateRenderer.builtin("layout"))
  end

  it "passes the template variables through" do
    expect(json["variables"]).to eq(variables)
  end

  it "lists the tags and filters templates may use" do
    expect(json["tags"]).to include("if", "for")
    expect(json["tags"]).not_to include("render", "include")
    expect(json["filters"]).to include("upcase", "squish", "h")
    expect(json["filters"]).to eq(json["filters"].uniq.sort)
  end
end
