# frozen_string_literal: true

describe "Composer - ProseMirror - Input rules", type: :system do
  include_context "with prosemirror editor"

  it "supports > to create a blockquote" do
    open_composer
    composer.type_content("> This is a blockquote")

    expect(rich).to have_css("blockquote", text: "This is a blockquote")
  end

  it "supports n. to create an ordered list" do
    open_composer
    composer.type_content("1. Item 1\n5. Item 2")

    expect(rich).to have_css("ol li", text: "Item 1")
    expect(find("ol ol", text: "Item 2")["start"]).to eq(5)
  end

  it "supports *, - or + to create an unordered list" do
    open_composer
    composer.type_content("* Item 1\n")
    composer.type_content("- Item 2\n")
    composer.type_content("+ Item 3")

    expect(rich).to have_css("ul ul li", count: 3)
  end

  it "uses 'tight' lists for both ordered and unordered lists by default" do
    open_composer
    composer.type_content("1. Item 1\n5. Item 2\n\n")
    composer.type_content("* Item 1\n* Item 2")
    expect(rich).to have_css("ol[data-tight='true']")
    expect(rich).to have_css("ul[data-tight='true']")
  end

  it "supports ``` or 4 spaces to create a code block" do
    open_composer
    composer.type_content("```\nThis is a code block")
    composer.send_keys(%i[shift enter])
    composer.type_content("    This is a code block")

    expect(rich).to have_css("pre code", text: "This is a code block", count: 2)
  end

  it "supports 1-6 #s to create a heading" do
    open_composer
    composer.type_content("# Heading 1\n")
    composer.type_content("## Heading 2\n")
    composer.type_content("### Heading 3\n")
    composer.type_content("#### Heading 4\n")
    composer.type_content("##### Heading 5\n")
    composer.type_content("###### Heading 6\n")

    expect(rich).to have_css("h1", text: "Heading 1")
    expect(rich).to have_css("h2", text: "Heading 2")
    expect(rich).to have_css("h3", text: "Heading 3")
    expect(rich).to have_css("h4", text: "Heading 4")
    expect(rich).to have_css("h5", text: "Heading 5")
    expect(rich).to have_css("h6", text: "Heading 6")
  end

  it "supports _ or * to create an italic text" do
    open_composer
    composer.type_content("_This is italic_\n")
    composer.type_content("Hey _This is italic_\n")
    composer.type_content("*This is italic*\n")
    composer.type_content("Hey*This is italic*\n")

    expect(rich).to have_css("em", text: "This is italic", count: 4)

    composer.toggle_rich_editor

    expect(composer).to have_value(
      "*This is italic*\n\nHey *This is italic*\n\n*This is italic*\n\nHey*This is italic*",
    )
  end

  it "supports __ or ** to create a bold text" do
    open_composer
    composer.type_content("__This is bold__\n\n")
    composer.type_content("**This is bold**\n\n")
    composer.type_content("Hey __This is bold__\n\n")
    composer.type_content("Hey**This is bold**")

    expect(rich).to have_css("strong", text: "This is bold", count: 4)

    composer.toggle_rich_editor

    expect(composer).to have_value(
      "**This is bold**\n\n**This is bold**\n\nHey **This is bold**\n\nHey**This is bold**",
    )
  end

  it "supports ` to create a code text" do
    open_composer
    composer.type_content("`This is code`")

    expect(rich).to have_css("code", text: "This is code")
  end

  it "supports typographer replacements" do
    open_composer
    composer.type_content(
      "foo +- bar... test???? wow!!!! x,, y-- --- a--> b<-- c-> d<- e<-> f<--> (tm) (pa)",
    )

    expect(rich).to have_css(
      "p",
      text: "foo ± bar… test??? wow!!! x, y– — a–> b←- c→ d← e←> f←→ ™ ¶",
    )
  end

  it "supports ---, ***, ___, en-dash+hyphen, em-dash+hyphen to create a horizontal rule" do
    open_composer
    composer.type_content("Hey\n---There\n*** Friend\n___ How\n\u2013-are\n\u2014-you")

    expect(rich).to have_css("hr", count: 5)
  end

  it "supports <http://example.com> to create an 'autolink'" do
    open_composer
    composer.type_content("<http://example.com>")

    expect(rich).to have_css("a", text: "http://example.com")

    composer.toggle_rich_editor

    expect(composer).to have_value("<http://example.com>")
  end

  it "supports [quote] to create a quote block" do
    open_composer
    composer.type_content("[quote]")

    expect(rich).to have_css("aside.quote blockquote")

    composer.toggle_rich_editor

    expect(composer).to have_value("[quote]\n\n[/quote]\n\n")
  end

  it "supports [quote=\"username\"] to create a quote block with attribution" do
    open_composer
    composer.type_content("[quote=\"johndoe\"]")

    expect(rich).to have_css("aside.quote[data-username='johndoe'] .title", text: "johndoe:")
    expect(rich).to have_css("aside.quote blockquote")

    composer.toggle_rich_editor

    expect(composer).to have_value("[quote=\"johndoe\"]\n\n[/quote]\n\n")
  end

  it "supports [quote=\"username, post:1, topic:123\"] to create a quote block with full attribution" do
    open_composer
    composer.type_content("[quote=\"johndoe, post:1, topic:123\"]")

    expect(rich).to have_css(
      "aside.quote[data-username='johndoe'][data-post='1'][data-topic='123'] .title",
      text: "johndoe:",
    )
    expect(rich).to have_css("aside.quote blockquote")

    composer.toggle_rich_editor

    expect(composer).to have_value("[quote=\"johndoe, post:1, topic:123\"]\n\n[/quote]\n\n")
  end

  it "doesn't trigger quote input rule in the middle of text" do
    open_composer
    composer.type_content("This [quote] should not trigger")

    expect(rich).to have_no_css("aside.quote")
    expect(rich).to have_content("This [quote] should not trigger")
  end

  it "avoids applying input rules in inline code if part of the matched text" do
    open_composer
    composer.type_content("This `__code` should not__ be bold. `and this, ")
    page.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "e"])
    # should not trigger the conversion of "and this, " to code as the 2nd ` is typed inside inline code
    composer.type_content("not code`")

    expect(rich).to have_no_css("strong")
    expect(rich).to have_css("code", text: "__code")

    expect(rich).to have_css("code", text: "not code")
    expect(rich).to have_no_css("code", text: "and this, not code")
  end

  it "doesn't apply input rules immediately after a single backtick" do
    open_composer
    composer.type_content("`**not bold**\n`:tada:")

    expect(rich).to have_no_css("strong")
    expect(rich).to have_no_css("img.emoji")

    composer.toggle_rich_editor

    expect(composer).to have_value("\\`\\*\\*not bold\\*\\*\n\n\\`:tada:")
  end
end
