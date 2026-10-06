# frozen_string_literal: true

RSpec.describe LlmsTxt do
  subject(:document) { described_class.generate }

  before do
    SiteSetting.default_locale = "en"
    SiteSetting.title = "Example Community"
    SiteSetting.site_description = "The official community and support forum."
    SiteSetting.short_site_description = "A shorter description."
    SiteSetting.login_required = false
    SiteSetting.enable_sitemap = true
  end

  it "uses the canonical site identity and produces deterministic Markdown" do
    expect(document).to start_with(
      "# Example Community\n\n> The official community and support forum.\n\n",
    )
    expect(document.scan(Discourse.base_url).length).to eq(1)
    expect(document).to end_with("\n")
    expect(document).not_to end_with("\n\n")
  end

  it "falls back to the short description and omits a blank description" do
    SiteSetting.site_description = "\u00a0"
    expect(document).to include("> A shorter description.\n")

    SiteSetting.short_site_description = ""
    expect(described_class.generate.lines.grep(/^> /)).to be_empty
  end

  it "falls back to a valid title and omits whitespace-only descriptions" do
    SiteSetting.title = "\u00a0"
    SiteSetting.site_description = "\u00a0"
    SiteSetting.short_site_description = "\u00a0"

    expect(document.lines.first.chomp).to eq("# #{Discourse.current_hostname}")
    expect(document.lines.grep(/^> /)).to be_empty
  end

  it "uses the site default locale regardless of the request locale" do
    baseline = document

    I18n.with_locale(:fr) { expect(described_class.generate).to eq(baseline) }
  end

  it "normalizes administrator-provided identity text without mangling punctuation" do
    SiteSetting.title = "C# Community\n## Injected heading"
    SiteSetting.site_description = "First line\r\n\r\n- Injected item"

    expect(document.lines.first.chomp).to eq("# C# Community ## Injected heading")
    expect(document.lines.grep(/^> /)).to eq(["> First line - Injected item\n"])
    expect(document.lines.grep(/^## Injected heading$/)).to be_empty
  end

  it "describes responsible agent behavior and the external MCP interface" do
    expect(document).to include(
      "community for human discussion",
      "Do not impersonate people or create accounts autonomously",
      "Only post, edit, or take another write action when a human explicitly asks you to perform that exact action",
      "Do not systematically crawl or bulk-download this community",
      "Respect `robots.txt`",
      "HTTP 429",
      "`Retry-After`",
      "[Discourse MCP setup](https://github.com/discourse/discourse-mcp#quick-start-release)",
      "Set its site URL to `#{Discourse.base_url}`",
    )
    expect(document).not_to include("#{Discourse.base_url}/mcp")
  end

  it "links to targeted public discovery, filtering, sitemap, and stable help routes" do
    expect(document).to include(
      "## Public web access",
      "[Search](/search)",
      "do not crawl result pages",
      "[Topic filter](/filter)",
      "with `?q=`",
      "`category:`",
      "[Latest discussions](/latest)",
      "[Categories](/categories)",
      "[Sitemap](/sitemap.xml)",
      "[About](/about)",
      "[Guidelines](/guidelines)",
      "[Terms of service](/tos)",
      "[Privacy policy](/privacy)",
    )
  end

  it "uses base-path-aware links on subfolder installs" do
    set_subfolder "/forum"

    expect(document).to include(
      "Set its site URL to `#{Discourse.base_url}`",
      "[Search](/forum/search)",
      "[Topic filter](/forum/filter)",
      "[Sitemap](/forum/sitemap.xml)",
      "[Privacy policy](/forum/privacy)",
    )
    local_targets = document.scan(%r{^- \[[^\]]+\]\((/[^)]+)\)}).flatten
    expect(local_targets).to all(start_with("/forum/"))
    expect(document.scan(Discourse.base_url).length).to eq(1)
  end

  it "omits sitemap when it is disabled" do
    SiteSetting.enable_sitemap = false

    expect(document).to include(
      "## Public web access",
      "[Search](/search)",
      "[Topic filter](/filter)",
      "[Latest discussions](/latest)",
      "[Categories](/categories)",
    )
    expect(document).not_to include("/sitemap.xml")
  end

  it "limits login-required sites to safe links and explains the account requirement" do
    SiteSetting.login_required = true

    expect(document).to include(
      "> The official community and support forum.",
      "Community content is available only to authenticated members.",
      "[Terms of service](/tos)",
      "[Privacy policy](/privacy)",
    )
    expect(document).not_to include(
      "## Public web access",
      "/search",
      "/filter",
      "/latest",
      "/categories",
      "/sitemap.xml",
      "/about",
      "/guidelines",
    )
  end

  it "keeps every link on one line and only emits list items below H2 headings" do
    list_items = document.lines.grep(/^- /)
    expect(list_items).to all(match(/\A- \[[^\]\r\n]+\]\([^)\r\n]+\): [^\r\n]+\n\z/))

    lines = document.lines(chomp: true)
    headings = lines.grep(/^## /)
    expect(headings.length).to eq(3)

    lines
      .each_index
      .select { |index| lines[index].start_with?("## ") }
      .each do |heading_index|
        section_end = lines[(heading_index + 1)..].index { |line| line.start_with?("## ") }
        section_lines =
          lines[
            (heading_index + 1)...(section_end ? heading_index + 1 + section_end : lines.length)
          ]
        content_lines = section_lines.reject(&:blank?)

        expect(content_lines).not_to be_empty
        expect(content_lines).to all(start_with("- ["))
      end
  end
end
