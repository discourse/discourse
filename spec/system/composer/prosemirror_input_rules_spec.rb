# frozen_string_literal: true

describe "Composer - ProseMirror - Input rules" do
  include_context "with prosemirror editor"

  it "supports > to create a blockquote" do
    open_composer
    composer.type_content("> This is a blockquote")

    expect(rich.locator("blockquote").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("This is a blockquote")],
      useInnerText: true,
    )
  end

  it "supports n. to create an ordered list" do
    open_composer
    composer.type_content("1. Item 1\n5. Item 2")

    expect(rich.locator("ol li").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Item 1")],
      useInnerText: true,
    )
    expect(
      browser_root
        .locator("ol ol")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern("Item 2"))
        .evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "start",
        ),
    ).to eq(5)
  end

  it "supports *, - or + to create an unordered list" do
    open_composer
    composer.type_content("* Item 1\n")
    composer.type_content("- Item 2\n")
    composer.type_content("+ Item 3")

    expect(rich.locator("ul ul li").filter(visible: true)).to PlaywrightMatchers.have_count(3)
  end

  it "uses 'tight' lists for both ordered and unordered lists by default" do
    open_composer
    composer.type_content("1. Item 1\n5. Item 2\n\n")
    composer.type_content("* Item 1\n* Item 2")
    expect(
      rich.locator("ol[data-tight='true']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      rich.locator("ul[data-tight='true']").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "supports ``` or 4 spaces to create a code block" do
    open_composer
    composer.type_content("```\nThis is a code block")
    browser_page.keyboard.press(%w[Shift Enter].join("+"))
    composer.type_content("    This is a code block")

    expect(
      rich
        .locator("pre code")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern("This is a code block")),
    ).to PlaywrightMatchers.have_count(2)
  end

  it "supports 1-6 #s to create a heading" do
    open_composer
    composer.type_content("# Heading 1\n")
    composer.type_content("## Heading 2\n")
    composer.type_content("### Heading 3\n")
    composer.type_content("#### Heading 4\n")
    composer.type_content("##### Heading 5\n")
    composer.type_content("###### Heading 6\n")

    expect(rich.locator("h1").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Heading 1")],
      useInnerText: true,
    )
    expect(rich.locator("h2").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Heading 2")],
      useInnerText: true,
    )
    expect(rich.locator("h3").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Heading 3")],
      useInnerText: true,
    )
    expect(rich.locator("h4").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Heading 4")],
      useInnerText: true,
    )
    expect(rich.locator("h5").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Heading 5")],
      useInnerText: true,
    )
    expect(rich.locator("h6").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Heading 6")],
      useInnerText: true,
    )
  end

  it "supports _ or * to create an italic text" do
    open_composer
    composer.type_content("_This is italic_\n")
    composer.type_content("Hey _This is italic_\n")
    composer.type_content("*This is italic*\n")
    composer.type_content("Hey*This is italic*\n")

    expect(
      rich
        .locator("em")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern("This is italic")),
    ).to PlaywrightMatchers.have_count(4)

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

    expect(
      rich
        .locator("strong")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern("This is bold")),
    ).to PlaywrightMatchers.have_count(4)

    composer.toggle_rich_editor

    expect(composer).to have_value(
      "**This is bold**\n\n**This is bold**\n\nHey **This is bold**\n\nHey**This is bold**",
    )
  end

  it "supports ` to create a code text" do
    open_composer
    composer.type_content("`This is code`")

    expect(rich.locator("code").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("This is code")],
      useInnerText: true,
    )
  end

  it "does not apply typographer replacements" do
    open_composer
    text = "foo +- bar... test???? wow!!!! x,, y-- --- a--> b<-- c-> d<- e<-> f<--> (tm) (pa)"
    composer.type_content(text)

    # Typographer replacements are disabled in the rich editor, so the text is
    # kept verbatim instead of being converted to ±, …, smart quotes, etc.
    expect(rich.locator("p").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern(text)],
      useInnerText: true,
    )
  end

  it "supports ---, ***, ___, en-dash+hyphen, em-dash+hyphen to create a horizontal rule" do
    open_composer
    composer.type_content("Hey\n---There\n*** Friend\n___ How\n\u2013-are\n\u2014-you")

    expect(rich.locator("hr").filter(visible: true)).to PlaywrightMatchers.have_count(5)
  end

  it "supports <http://example.com> to create an 'autolink'" do
    open_composer
    composer.type_content("<http://example.com>")

    expect(rich.locator("a").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("http://example.com")],
      useInnerText: true,
    )

    composer.toggle_rich_editor

    expect(composer).to have_value("<http://example.com>")
  end

  it "supports [quote] to create a quote block" do
    open_composer
    composer.type_content("[quote]")

    expect(
      rich.locator("aside.quote blockquote").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    composer.toggle_rich_editor

    expect(composer).to have_value("[quote]\n\n[/quote]\n\n")
  end

  it "supports [quote=\"username\"] to create a quote block with attribution" do
    open_composer
    composer.type_content("[quote=\"johndoe\"]")

    expect(
      rich.locator("aside.quote[data-username='johndoe'] .title").filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("johndoe:")], useInnerText: true)
    expect(
      rich.locator("aside.quote blockquote").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    composer.toggle_rich_editor

    expect(composer).to have_value("[quote=\"johndoe\"]\n\n[/quote]\n\n")
  end

  it "supports [quote=\"username, post:1, topic:123\"] to create a quote block with full attribution" do
    open_composer
    composer.type_content("[quote=\"johndoe, post:1, topic:123\"]")

    expect(
      rich.locator(
        "aside.quote[data-username='johndoe'][data-post='1'][data-topic='123'] .title",
      ).filter(visible: true),
    ).to PlaywrightMatchers.contain_text([browser_text_pattern("johndoe:")], useInnerText: true)
    expect(
      rich.locator("aside.quote blockquote").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    composer.toggle_rich_editor

    expect(composer).to have_value("[quote=\"johndoe, post:1, topic:123\"]\n\n[/quote]\n\n")
  end

  it "doesn't trigger quote input rule in the middle of text" do
    open_composer
    composer.type_content("This [quote] should not trigger")

    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("aside.quote")
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(rich).to PlaywrightMatchers.contain_text(
      browser_text_pattern("This [quote] should not trigger"),
      useInnerText: true,
    )
  end

  it "avoids applying input rules in inline code if part of the matched text" do
    open_composer
    composer.type_content("This `__code` should not__ be bold. `and this, ")
    browser_page.keyboard.press(
      [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "e"].join("+"),
    )
    # should not trigger the conversion of "and this, " to code as the 2nd ` is typed inside inline code
    composer.type_content("not code`")

    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("strong")
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(rich.locator("code").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("__code")],
      useInnerText: true,
    )

    expect(rich.locator("code").filter(visible: true)).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("not code")],
      useInnerText: true,
    )
    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("code")
        .filter(visible: true),
    ).not_to PlaywrightMatchers.contain_text(
      [browser_text_pattern("and this, not code")],
      useInnerText: true,
    )
  end

  it "does not convert emoji shortcuts when enable_emoji_shortcuts is disabled" do
    SiteSetting.enable_emoji_shortcuts = false
    open_composer

    composer.type_content(":) ")

    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("img.emoji")
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(rich).to PlaywrightMatchers.contain_text(browser_text_pattern(":)"), useInnerText: true)
  end

  it "doesn't apply input rules immediately after a single backtick" do
    open_composer
    composer.type_content("`**not bold**\n`:tada:")

    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("strong")
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    expect(
      rich
        .tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end
        .locator("img.emoji")
        .filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    composer.toggle_rich_editor

    expect(composer).to have_value("\\`\\*\\*not bold\\*\\*\n\n\\`:tada:")
  end
end
