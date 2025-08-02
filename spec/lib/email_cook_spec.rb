# frozen_string_literal: true

require "email_cook"
require "pretty_text"

RSpec.describe EmailCook do
  it "uses to PrettyText when there is no [plaintext] in raw" do
    raw = "**Hello world!**"
    expect(cook(raw)).to eq(PrettyText.cook(raw))
  end

  it "adds linebreaks to short lines" do
    raw = plaintext("hello\nworld\n")
    expect(cook(raw)).to eq("hello\n<br>world\n<br>")
  end

  it "doesn't add linebreaks to long lines" do
    long = plaintext(<<~EMAIL)
      Hello,

      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis volutpat
      risus. Nulla ac faucibus quam, quis cursus lorem. Sed rutrum eget nunc sed accumsan.
      Vestibulum feugiat mi vitae turpis tempor dignissim.
    EMAIL

    long_cooked = (+<<~HTML).strip!
      Hello,
      <br>
      <br>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis volutpat
      risus. Nulla ac faucibus quam, quis cursus lorem. Sed rutrum eget nunc sed accumsan.
      Vestibulum feugiat mi vitae turpis tempor dignissim.
      <br>
    HTML

    expect(cook(long)).to eq(long_cooked)
  end

  it "replaces a blank line with 2 linebreaks" do
    long = plaintext(<<~EMAIL)
      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis volutpat
      risus.
      Nulla ac faucibus quam, quis cursus lorem. Sed rutrum eget nunc sed accumsan.

      Vestibulum feugiat mi vitae turpis tempor dignissim.

      Stet clita kasd gubergren.
    EMAIL

    long_cooked = (+<<~HTML).strip!
      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis volutpat
      risus.
      <br>Nulla ac faucibus quam, quis cursus lorem. Sed rutrum eget nunc sed accumsan.
      <br>
      <br>Vestibulum feugiat mi vitae turpis tempor dignissim.
      <br>
      <br>Stet clita kasd gubergren.
      <br>
    HTML

    expect(cook(long)).to eq(long_cooked)
  end

  it "escapes HTML" do
    long = plaintext(<<~EMAIL)
      Lorem ipsum dolor sit amet, consectetur adipiscing elit.

      <form name="f1" method="post" action="test.html" onsubmit="javascript:showAlert()">
      <input type="submit" name="submit" value="Click this button" />
      </form>

      Nunc convallis volutpat risus.
    EMAIL

    long_cooked = (+<<~HTML).strip!
      Lorem ipsum dolor sit amet, consectetur adipiscing elit.
      <br>
      <br>&lt;form name=&quot;f1&quot; method=&quot;post&quot; action=&quot;test.html&quot; onsubmit=&quot;javascript:showAlert()&quot;&gt;
      &lt;input type=&quot;submit&quot; name=&quot;submit&quot; value=&quot;Click this button&quot; /&gt;
      &lt;/form&gt;
      <br>
      <br>Nunc convallis volutpat risus.
      <br>
    HTML

    expect(cook(long)).to eq(long_cooked)
  end

  it "replaces indentation of more than 2 spaces with corresponding amount of non-breaking spaces" do
    nbsp = "\u00A0"
    long = plaintext(<<~EMAIL)
      Lorem ipsum dolor sit amet, consectetur adipiscing elit.

          this is intended by 4 spaces
       this is intended by 1 space
      no indentation, but lots       of spaces
    EMAIL

    long_cooked = (+<<~HTML).strip!
      Lorem ipsum dolor sit amet, consectetur adipiscing elit.
      <br>
      <br>#{nbsp}#{nbsp}#{nbsp}#{nbsp}this is intended by 4 spaces
      <br> this is intended by 1 space
      <br>no indentation, but lots       of spaces
      <br>
    HTML

    expect(cook(long)).to eq(long_cooked)
  end

  it "creates oneboxed link when the line contains only a link" do
    raw = plaintext("https://www.eviltrout.com")
    expect(cook(raw)).to eq(
      '<a href="https://www.eviltrout.com" class="onebox" target="_blank">https://www.eviltrout.com</a><br>',
    )
  end

  it "autolinks without the beginning of a line" do
    raw = plaintext("my site: https://www.eviltrout.com")
    expect(cook(raw)).to eq(
      'my site: <a href="https://www.eviltrout.com">https://www.eviltrout.com</a><br>',
    )
  end

  it "autolinks without the end of a line" do
    raw = plaintext("https://www.eviltrout.com is my site")
    expect(cook(raw)).to eq(
      '<a href="https://www.eviltrout.com">https://www.eviltrout.com</a> is my site<br>',
    )
  end

  it "links even within a quote" do
    raw = plaintext("> https://www.eviltrout.com is my site")
    expect(cook(raw)).to eq(
      '<blockquote><a href="https://www.eviltrout.com">https://www.eviltrout.com</a> is my site<br></blockquote>',
    )
  end

  it "it works and does not interpret Markdown in plaintext and elided" do
    long = <<~EMAIL
      [plaintext]
      *Lorem ipsum* dolor sit amet, consectetur adipiscing elit.
      [/plaintext]
      [attachments]
      <img src='some_image.png' width='100' height='100'>
      [/attachments]
      [elided]
      At vero eos *et accusam* et justo duo dolores et ea rebum.
      [/elided]
    EMAIL

    long_cooked = <<~HTML
      *Lorem ipsum* dolor sit amet, consectetur adipiscing elit.<br>
      <br><img src='some_image.png' width='100' height='100'>
      <br><br>

      <details class='elided'>
      <summary title='Show trimmed content'>&#183;&#183;&#183;</summary>

      At vero eos *et accusam* et justo duo dolores et ea rebum.<br>

      </details>
    HTML

    expect(cook(long)).to eq(long_cooked)
  end

  it "works without attachments" do
    long = <<~EMAIL
      [plaintext]
      *Lorem ipsum* dolor sit amet, consectetur adipiscing elit.
      [/plaintext]
      [elided]
      At vero eos *et accusam* et justo duo dolores et ea rebum.
      [/elided]
    EMAIL

    long_cooked = <<~HTML
      *Lorem ipsum* dolor sit amet, consectetur adipiscing elit.<br>
      <br><br>

      <details class='elided'>
      <summary title='Show trimmed content'>&#183;&#183;&#183;</summary>

      At vero eos *et accusam* et justo duo dolores et ea rebum.<br>

      </details>
    HTML

    expect(cook(long)).to eq(long_cooked)
  end

  def cook(raw)
    EmailCook.new(raw).cook
  end

  def plaintext(text)
    "[plaintext]\n#{text}\n[/plaintext]"
  end
end
