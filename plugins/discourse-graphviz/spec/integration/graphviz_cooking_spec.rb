# frozen_string_literal: true

RSpec.describe "Graphviz cooking" do
  before { SiteSetting.discourse_graphviz_enabled = true }

  it "emits a placeholder with the engine and escaped source for the client to render" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz engine=neato]
        digraph G { a -> b }
        [/graphviz]
      MD

    expect(post.cooked).to include("graphviz is-loading")
    expect(post.cooked).to include("neato")
    expect(post.cooked).to include("digraph G { a -&gt; b }")
  end

  it "defaults to the dot engine for unknown engines" do
    post = Fabricate(:post, raw: "[graphviz engine=bogus]\ndigraph { a }\n[/graphviz]")

    expect(post.cooked).to include("dot")
    expect(post.cooked).not_to include("bogus")
  end

  it "does not render when the plugin is disabled" do
    SiteSetting.discourse_graphviz_enabled = false
    post = Fabricate(:post, raw: "[graphviz]\ndigraph { a }\n[/graphviz]")

    expect(post.cooked).not_to include("class=\"graphviz")
  end
end
