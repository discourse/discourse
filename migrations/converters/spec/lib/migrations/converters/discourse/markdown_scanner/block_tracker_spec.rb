# frozen_string_literal: true

# Every expectation here is copied from a row of `code_parity_spec.rb`, which
# derives it from `PrettyText.cook`. The parity spec only runs in the Rails job;
# this one guards the same truths on every run.
RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::BlockTracker do
  # Drives the tracker the way the {Scanner} does — one call per line start — and
  # returns the raw text of every region it claimed as code.
  def code_regions(input)
    tracker = described_class.new
    regions = []
    pos = 0
    length = input.bytesize

    while pos < length
      consumed = tracker.process_line(input, pos)
      if consumed
        regions << input.byteslice(pos...consumed)
        pos = consumed
      else
        line_end = input.byteindex("\n", pos) || length
        pos = line_end < length ? line_end + 1 : length
      end
    end

    regions
  end

  def code_text(input)
    code_regions(input).join
  end

  describe "fenced code" do
    it "claims the opener, the body and the closer" do
      expect(code_regions("```\nbody\n```\nafter\n")).to eq(["```\n", "body\n", "```\n"])
    end

    it "runs to the end of input when the fence is never closed" do
      expect(code_text("```\nbody\n")).to eq("```\nbody\n")
    end

    it "does not close on the other fence character" do
      expect(code_text("```\na\n~~~\n```\nafter\n")).to eq("```\na\n~~~\n```\n")
    end

    it "does not close on a shorter run" do
      expect(code_text("````\na\n```\nafter\n")).to eq("````\na\n```\nafter\n")
    end

    it "closes on a run indented three columns" do
      expect(code_text("```\na\n   ```\nafter\n")).to eq("```\na\n   ```\n")
    end

    it "does not close on a run indented four columns" do
      expect(code_text("  ```\na\n      ```\n")).to eq("  ```\na\n      ```\n")
    end

    it "does not close on a run with text after it" do
      expect(code_text("```\na\n``` tail\nafter\n")).to eq("```\na\n``` tail\nafter\n")
    end

    # Reading such a line as a fence would swallow the rest of the post as code.
    it "leaves a backtick fence whose info string holds a backtick as prose" do
      expect(code_regions("``` a`b\nbody\n")).to be_empty
    end

    it "accepts a backtick in a tilde fence's info string" do
      expect(code_text("~~~ a`b\nbody\n~~~\n")).to eq("~~~ a`b\nbody\n~~~\n")
    end

    it "keeps a blank line inside the block" do
      expect(code_text("```\na\n\nb\n```\n")).to eq("```\na\n\nb\n```\n")
    end
  end

  describe "indented code" do
    it "opens after a blank line" do
      expect(code_text("Intro\n\n    body\n")).to eq("    body\n")
    end

    it "opens at the start of input" do
      expect(code_text("    body\n")).to eq("    body\n")
    end

    it "opens right after a heading, with no blank line between" do
      expect(code_text("# Title\n    body\n")).to eq("    body\n")
    end

    it "opens right after a closed fence" do
      expect(code_text("```\nx\n```\n    body\n")).to eq("```\nx\n```\n    body\n")
    end

    # An indented line inside an open paragraph is a lazy continuation.
    it "does not open in the middle of a paragraph" do
      expect(code_regions("Intro\n    body\n")).to be_empty
    end

    it "opens at a tab" do
      expect(code_text("Intro\n\n\tbody\n")).to eq("\tbody\n")
    end

    it "opens where a space and a tab reach column four" do
      expect(code_text("Intro\n\n \tbody\n")).to eq(" \tbody\n")
    end

    it "does not open at two columns" do
      expect(code_regions("Intro\n\n  body\n")).to be_empty
    end

    it "keeps a blank line between its chunks" do
      expect(code_text("Intro\n\n    a\n\n    b\n")).to eq("    a\n\n    b\n")
    end

    it "closes on an unindented line and reopens later" do
      expect(code_text("Intro\n\n    a\ntext\n\n    b\n")).to eq("    a\n    b\n")
    end
  end

  describe "indented code inside containers" do
    it "needs six columns under a bullet, not four" do
      expect(code_regions("- item\n\n    body\n")).to be_empty
      expect(code_text("- item\n\n      body\n")).to eq("      body\n")
    end

    it "needs seven columns under a numbered step" do
      expect(code_regions("1. Step\n\n    body\n")).to be_empty
      expect(code_text("1. Step\n\n       body\n")).to eq("       body\n")
    end

    # More than four spaces after the marker put the content one column past it,
    # so the threshold stays six rather than moving out with the text — which is
    # also why the item's own text is already code here.
    it "ignores padding past four spaces when placing the content column" do
      expect(code_text("-     item\n\n     body\n")).to eq("-     item\n\n")
      expect(code_text("-     item\n\n      body\n")).to eq("-     item\n\n      body\n")
    end

    it "counts a tab after the marker to the next tab stop" do
      expect(code_text("-\titem\n\n\t\tbody\n")).to eq("\t\tbody\n")
    end

    it "needs eight columns inside a nested bullet" do
      expect(code_regions("- a\n\n  - b\n\n      body\n")).to be_empty
      expect(code_text("- a\n\n  - b\n\n        body\n")).to eq("        body\n")
    end

    it "measures from inside a blockquote" do
      expect(code_text("> Intro\n>\n>     body\n")).to eq(">     body\n")
    end

    it "reopens at four columns once the list has ended" do
      expect(code_text("- item\n\ntext\n\n    body\n")).to eq("    body\n")
    end
  end

  describe "fenced code inside containers" do
    it "claims a fence inside a blockquote, marker and all" do
      expect(code_text("> ```\n> body\n> ```\n")).to eq("> ```\n> body\n> ```\n")
    end

    it "claims a fence inside a list item" do
      expect(code_text("- item\n\n  ```\n  body\n  ```\n")).to eq("  ```\n  body\n  ```\n")
    end

    # A fenced block is not lazily continued, so a line without the marker ends
    # the blockquote and the fence with it; the line after opens a fresh one.
    it "ends a blockquote's fence at a line without the marker" do
      expect(code_regions("> ```\nbody\n> ```\n")).to eq(["> ```\n", "> ```\n"])
    end

    it "closes a list when the fence starts back at column zero" do
      expect(code_text("- item\n\n```\nbody\n```\n")).to eq("```\nbody\n```\n")
    end
  end

  describe "[code] blocks" do
    it "claims the opener line through the closer line" do
      expect(code_text("[code]\nbody\n[/code]\nafter\n")).to eq("[code]\nbody\n[/code]\n")
    end

    it "accepts an attribute on the opener" do
      expect(code_text("[code=ruby]\nbody\n[/code]\n")).to eq("[code=ruby]\nbody\n[/code]\n")
      expect(code_text("[code lang=ruby]\nb\n[/code]\n")).to eq("[code lang=ruby]\nb\n[/code]\n")
    end

    it "matches the tags case-insensitively" do
      expect(code_text("[CODE]\nbody\n[/CODE]\n")).to eq("[CODE]\nbody\n[/CODE]\n")
    end

    it "allows trailing spaces after the opener" do
      expect(code_text("[code]  \nbody\n[/code]\n")).to eq("[code]  \nbody\n[/code]\n")
    end

    it "counts nested openers" do
      raw = "[code]\n[code]\nbody\n[/code]\n[/code]\n"

      expect(code_text(raw)).to eq(raw)
    end

    # These two drive the close memo: the failed scan from the first opener
    # already settles the second one's fate, and the block (or its absence)
    # must come out the same when that answer is replayed.
    it "pairs a lone closer with the innermost opener" do
      expect(code_text("[code]\n[code]\nbody\n[/code]\nafter\n")).to eq("[code]\nbody\n[/code]\n")
    end

    it "declines every opener when none is ever closed" do
      expect(code_regions("[code]\n[code]\nbody\n")).to be_empty
    end

    it "claims a whole line that opens and closes on itself" do
      expect(code_text("[code]body[/code]\nafter\n")).to eq("[code]body[/code]\n")
    end

    # The block form declines here; the inline form (see #code_tag_span_end)
    # picks both of these up instead.
    it "declines a closer with text after it" do
      expect(code_regions("[code]body[/code] tail\n")).to be_empty
      expect(code_regions("[code]\nbody\n[/code] x\n")).to be_empty
    end

    it "declines a closer indented four columns" do
      expect(code_regions("[code]\nbody\n    [/code]\n")).to be_empty
    end

    it "accepts a closer indented three columns" do
      expect(code_text("[code]\nbody\n   [/code]\n")).to eq("[code]\nbody\n   [/code]\n")
    end

    it "declines an unclosed opener" do
      expect(code_regions("[code]\nbody\n")).to be_empty
    end

    it "claims a block inside a blockquote" do
      expect(code_text("> [code]\n> body\n> [/code]\n")).to eq("> [code]\n> body\n> [/code]\n")
    end

    it "declines when the closer leaves the blockquote" do
      expect(code_regions("> [code]\n> body\n[/code]\n")).to be_empty
    end

    it "claims a block inside a list item" do
      raw = "  [code]\n  body\n  [/code]\n"

      expect(code_text("- item\n\n#{raw}")).to eq(raw)
    end

    it "ignores a closing tag that opens nothing" do
      expect(code_regions("[/code]\nbody\n")).to be_empty
    end

    it "ignores another bbcode tag" do
      expect(code_regions("[quote=\"bob\"]\nbody\n[/quote]\n")).to be_empty
    end
  end

  describe "<pre> blocks" do
    it "claims through the line holding the closing tag" do
      expect(code_text("<pre>\nbody\n</pre>\nafter\n")).to eq("<pre>\nbody\n</pre>\n")
    end

    it "claims a one-line block" do
      expect(code_text("<pre>body</pre>\nafter\n")).to eq("<pre>body</pre>\n")
    end

    it "claims whatever else sits on the closing line" do
      expect(code_text("<pre>\nx\n</pre> tail\nafter\n")).to eq("<pre>\nx\n</pre> tail\n")
    end

    it "accepts attributes and mixed case" do
      expect(code_text("<PRE class=\"x\">\nb\n</pre>\n")).to eq("<PRE class=\"x\">\nb\n</pre>\n")
    end

    # Core's type-1 HTML block behaves the same way.
    it "runs to the end of input when never closed" do
      expect(code_text("<pre>\nbody\nmore\n")).to eq("<pre>\nbody\nmore\n")
    end

    it "ends where its blockquote does" do
      expect(code_text("> <pre>\n> body\n> </pre>\n")).to eq("> <pre>\n> body\n> </pre>\n")
    end

    it "leaves a tag that only starts like <pre> as prose" do
      expect(code_regions("<pretty>\nbody\n")).to be_empty
    end

    it "leaves an indented <pre> to the indented-code rule" do
      expect(code_text("    <pre>\nbody\n</pre>\n")).to eq("    <pre>\n")
    end
  end

  describe "setext underlines, thematic breaks and empty list items" do
    it "closes the paragraph at an underline, so indented code opens below" do
      expect(code_text("Intro\n-\n    body\n")).to eq("    body\n")
      expect(code_text("Intro\n--\n    body\n")).to eq("    body\n")
      expect(code_text("Intro\n===\n    body\n")).to eq("    body\n")
      expect(code_text("Intro\n-  \n    body\n")).to eq("    body\n")
    end

    it "closes the paragraph at a thematic break, spaced or not" do
      expect(code_text("Intro\n***\n    body\n")).to eq("    body\n")
      expect(code_text("- - -\n    body\n")).to eq("    body\n")
    end

    it "reads a lone dash with no paragraph above as an empty list item" do
      expect(code_regions("-\n    body\n")).to be_empty
      expect(code_text("-\n      body\n")).to eq("      body\n")
    end

    it "reads an underline-shaped line with no paragraph above as prose" do
      expect(code_regions("=\n    body\n")).to be_empty
      expect(code_regions("--\n    body\n")).to be_empty
      expect(code_regions("==\n    body\n")).to be_empty
    end

    it "does not read a spaced run as an underline" do
      expect(code_regions("Intro\n= =\n    body\n")).to be_empty
      expect(code_regions("Intro\n- -\n    body\n")).to be_empty
    end

    # A setext underline is not one of core's container terminator rules, so
    # such a line continues the paragraph lazily.
    it "keeps an underline-shaped line lazy where the containers stop matching" do
      expect(code_regions("> Intro\n=\n    body\n")).to be_empty
      expect(code_regions("> Intro\n--\n    body\n")).to be_empty
      expect(code_regions("- Intro\n=\n      body\n")).to be_empty
    end

    # The terminator rules run with the container as the parent, so the list
    # paragraph restrictions do not apply: even an empty item ends the
    # containers, and its content column decides what is indented below it.
    it "ends a blockquote at an empty list item" do
      expect(code_regions("> Intro\n-\n    body\n")).to be_empty
      expect(code_text("> Intro\n-\n      body\n")).to eq("      body\n")
      expect(code_text("> Intro\n*\n      body\n")).to eq("      body\n")
    end

    it "ends a list item at an empty item with another marker" do
      expect(code_regions("- Intro\n-\n    body\n")).to be_empty
      expect(code_text("- Intro\n*\n      body\n")).to eq("      body\n")
    end

    it "ends a blockquote at an ordered item not starting at one" do
      expect(code_regions("> Intro\n2. x\n\n     body\n")).to be_empty
      expect(code_text("> Intro\n2. x\n\n       body\n")).to eq("       body\n")
    end

    it "keeps such a list item lazy at the paragraph's own level" do
      expect(code_regions("Intro\n*\n    body\n")).to be_empty
      expect(code_regions("Intro\n2. x\n    body\n")).to be_empty
    end
  end

  describe "CRLF bodies" do
    it "reads a blank line, a fence closer and a [code] closer through the CR" do
      expect(code_text("```\r\nbody\r\n```\r\n")).to eq("```\r\nbody\r\n```\r\n")
      expect(code_text("Intro\r\n\r\n    body\r\n")).to eq("    body\r\n")
      expect(code_text("[code]\r\nbody\r\n[/code]\r\n")).to eq("[code]\r\nbody\r\n[/code]\r\n")
    end
  end

  describe "#backtick_span_end" do
    def span_end(input, pos = 0)
      described_class.new.backtick_span_end(input, pos)
    end

    it "returns the offset past a closed span" do
      expect(span_end("`a` x")).to eq(3)
    end

    it "returns the offset past the run when nothing closes it" do
      expect(span_end("`a x")).to eq(1)
    end

    it "closes only on a run of the same length" do
      expect(span_end("``a`b`` x")).to eq(7)
    end

    it "crosses a single newline" do
      expect(span_end("`a\nb` x")).to eq(5)
    end

    it "stops at a blank line" do
      expect(span_end("`a\n\nb` x")).to eq(1)
    end

    # Block structure is decided before inline spans, so a line that interrupts
    # the paragraph leaves the opener literal.
    ["# h", "```", "---", "***", "- b", "1. b", "> b", "[quote=\"b\"]"].each do |interrupter|
      it "stops at a #{interrupter.inspect} line" do
        expect(span_end("`a\n#{interrupter}\nc` x")).to eq(1)
      end
    end

    it "stops at a table's header row" do
      expect(span_end("`a\nb|c\n-|-\nd` x")).to eq(1)
    end

    it "crosses an indented line, which cannot interrupt a paragraph" do
      expect(span_end("`a\n    b\nc` x")).to eq(11)
    end

    it "crosses a spaced run, which is no underline and no break" do
      expect(span_end("`a\n= =\nc` x")).to eq(9)
    end
  end

  describe "#code_tag_span_end" do
    def span_end(input, pos = 0)
      described_class.new.code_tag_span_end(input, pos)
    end

    it "returns the offset past the closer" do
      expect(span_end("[code]a[/code] x")).to eq(14)
    end

    it "matches the closer case-insensitively" do
      expect(span_end("[code]a[/CODE] x")).to eq(14)
    end

    it "matches greedily over interior brackets" do
      expect(span_end("[code]a[b][/code] x")).to eq(17)
    end

    it "crosses a newline inside the paragraph" do
      expect(span_end("[code]a\nb[/code] x")).to eq(16)
    end

    it "returns nil across a blank line" do
      expect(span_end("[code]a\n\nb[/code]")).to be_nil
    end

    it "returns nil without a closer" do
      expect(span_end("[code]a x")).to be_nil
    end

    it "returns nil for a closing tag" do
      expect(span_end("[/code] x")).to be_nil
    end

    it "returns nil for another bbcode tag" do
      expect(span_end("[quote]a[/quote]")).to be_nil
    end
  end
end
