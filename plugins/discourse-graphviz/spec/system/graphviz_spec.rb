# frozen_string_literal: true

describe "Graphviz" do
  fab!(:admin)
  fab!(:topic)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.discourse_graphviz_enabled = true
    sign_in(admin)
  end

  it "renders the graph on the client and opens the fullscreen popup" do
    post = Fabricate(:post, topic:, raw: <<~RAW)
        [graphviz]
        digraph G { a -> b; b -> c; }
        [/graphviz]
      RAW

    topic_page.visit_topic(post.topic)

    expect(page).to have_css(".graphviz-wrapper .graphviz-diagram svg")

    # revealed on hover; visible: :all avoids racing the opacity transition
    find(".graphviz-wrapper").hover
    find(".graphviz-fullscreen-button", visible: :all).click

    expect(page).to have_css(".d-modal.graphviz-fullscreen .graphviz-diagram svg")
  end

  it "shows an error message for invalid syntax" do
    post = Fabricate(:post, topic:, raw: "[graphviz]\ndigraph G { a -> }\n[/graphviz]")

    topic_page.visit_topic(post.topic)

    expect(page).to have_css(".graphviz-wrapper .graph-error")
  end
end
