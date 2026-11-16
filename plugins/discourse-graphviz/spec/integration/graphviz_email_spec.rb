# frozen_string_literal: true

RSpec.describe "Graphviz in emails" do
  before { SiteSetting.discourse_graphviz_enabled = true }

  let(:post) { Fabricate(:post, raw: "[graphviz]\ndigraph G { a -> b }\n[/graphviz]") }

  it "replaces the graph with a link to the post" do
    expect(PrettyText.format_for_email(post.cooked, post)).to match_html(
      %(<p><a href="#{post.full_url}">#{I18n.t("emails.view_diagram")}</a></p>),
    )
  end

  it "keeps the graph when there is no post to link to" do
    expect(PrettyText.format_for_email(post.cooked)).to include("digraph G")
  end
end
