# frozen_string_literal: true

RSpec.describe "Graphviz" do
  before do
    SiteSetting.discourse_graphviz_enabled = true
    SiteSetting.graphviz_default_svg = true
  end

  it "strips anchor elements with javascript: URLs to prevent XSS" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz]
        digraph G { a [label="XSS", URL="javascript:alert(1)"] }
        [/graphviz]
      MD

    cp = CookedPostProcessor.new(post)
    cp.post_process

    expect(cp.html).not_to include("javascript:")
    expect(cp.html).to include("graphviz-svg-render")
    expect(cp.html).to include("<text")
  end

  it "preserves legitimate HTTP and HTTPS URLs" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz]
        digraph G {
          a [label="HTTP", URL="http://example.com"]
          b [label="HTTPS", URL="https://example.com"]
          a -> b
        }
        [/graphviz]
      MD

    cp = CookedPostProcessor.new(post)
    cp.post_process

    expect(cp.html).to include('href="http://example.com"')
    expect(cp.html).to include('href="https://example.com"')
    expect(cp.html).to include("<a")
  end

  it "strips mailto: URLs" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz]
        digraph G { a [label="Email", URL="mailto:test@example.com"] }
        [/graphviz]
      MD

    cp = CookedPostProcessor.new(post)
    cp.post_process

    expect(cp.html).not_to include("mailto:")
  end

  it "strips anchor elements with data: URLs to prevent XSS" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz]
        digraph G { a [label="Data", URL="data:text/html,<script>alert(1)</script>"] }
        [/graphviz]
      MD

    cp = CookedPostProcessor.new(post)
    cp.post_process

    expect(cp.html).not_to include("data:")
    expect(cp.html).not_to include("alert")
  end

  it "strips anchor elements with vbscript: URLs to prevent XSS" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz]
        digraph G { a [label="VBScript", URL="vbscript:alert(1)"] }
        [/graphviz]
      MD

    cp = CookedPostProcessor.new(post)
    cp.post_process

    expect(cp.html).not_to include("vbscript:")
  end

  it "strips anchor elements with file: URLs" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz]
        digraph G { a [label="File", URL="file:///etc/passwd"] }
        [/graphviz]
      MD

    cp = CookedPostProcessor.new(post)
    cp.post_process

    expect(cp.html).not_to include("file:")
  end

  it "handles case-insensitive javascript: URLs" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz]
        digraph G { a [label="XSS", URL="JaVaScRiPt:alert(1)"] }
        [/graphviz]
      MD

    cp = CookedPostProcessor.new(post)
    cp.post_process

    expect(cp.html).not_to include("JaVaScRiPt:")
    expect(cp.html).not_to include("javascript:")
  end

  it "preserves relative URLs" do
    post = Fabricate(:post, raw: <<~MD)
        [graphviz]
        digraph G { a [label="Relative", URL="/some/path"] }
        [/graphviz]
      MD

    cp = CookedPostProcessor.new(post)
    cp.post_process

    expect(cp.html).to include('href="/some/path"')
    expect(cp.html).to include("<a")
  end
end
