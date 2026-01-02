# frozen_string_literal: true

describe PrettyText do
  before { SiteSetting.discourse_math_enabled = true }

  describe "inline math with $...$" do
    it "renders basic inline math" do
      expect(PrettyText.cook("I like $x^2$ etc")).to match_html(
        '<p>I like <span class="math">x^2</span> etc</p>',
      )
    end

    it "escapes HTML in math content" do
      expect(PrettyText.cook('I like $\{a,b\}\$<a>$ etc')).to match_html(
        '<p>I like <span class="math">\{a,b\}\$&lt;a&gt;</span> etc</p>',
      )
    end

    describe "boundary requirements" do
      it "requires safe boundary before opening $" do
        expect(PrettyText.cook("word$a$")).to match_html("<p>word$a$</p>")
        expect(PrettyText.cook("y$+500$")).to match_html("<p>y$+500$</p>")
      end

      it "requires safe boundary after closing $" do
        expect(PrettyText.cook("$a$word")).to match_html("<p>$a$word</p>")
        expect(PrettyText.cook("$+500$x")).to match_html("<p>$+500$x</p>")
      end

      it "works with whitespace boundaries" do
        expect(PrettyText.cook("$a$ word")).to match_html('<p><span class="math">a</span> word</p>')
        expect(PrettyText.cook("word $a$")).to match_html('<p>word <span class="math">a</span></p>')
        expect(PrettyText.cook("$+500$")).to match_html('<p><span class="math">+500</span></p>')
      end

      it "works with punctuation boundaries" do
        expect(PrettyText.cook(",$a$,")).to match_html('<p>,<span class="math">a</span>,</p>')
        expect(PrettyText.cook("($a$)")).to match_html('<p>(<span class="math">a</span>)</p>')
      end

      it "works with CJK punctuation" do
        expect(PrettyText.cook("测试，$a^2$，测试")).to match_html(
          '<p>测试，<span class="math">a^2</span>，测试</p>',
        )
        expect(PrettyText.cook("テスト、$a^2$、テスト")).to match_html(
          '<p>テスト、<span class="math">a^2</span>、テスト</p>',
        )
      end

      it "does not match escaped dollar signs" do
        expect(PrettyText.cook(',$+500\$')).to match_html("<p>,$+500$</p>")
      end

      it "does not treat dollar amounts as math" do
        expect(PrettyText.cook("200$ + 500$")).to match_html("<p>200$ + 500$</p>")
        expect(PrettyText.cook("costs $50 to $100")).to match_html("<p>costs $50 to $100</p>")
      end
    end
  end

  describe "block math with $$...$$" do
    it "renders single-line block math" do
      expect(PrettyText.cook("$$x^2 + y^2$$")).to match_html(
        "<div class=\"math\">\nx^2 + y^2\n</div>",
      )
    end

    it "renders multi-line block math" do
      expect(PrettyText.cook("$$\nx^2 + y^2\n$$")).to match_html(
        "<div class=\"math\">\nx^2 + y^2\n</div>",
      )
    end

    it "escapes HTML in block math" do
      expect(PrettyText.cook("$$\n<script>alert('xss')</script>\n$$")).to match_html(
        "<div class=\"math\">\n&lt;script&gt;alert('xss')&lt;/script&gt;\n</div>",
      )
    end

    it "renders block math between paragraphs" do
      expect(PrettyText.cook("Before\n$$\na^2\n$$\nAfter")).to match_html(
        "<p>Before</p>\n<div class=\"math\">\na^2\n</div>\n<p>After</p>",
      )
    end

    it "does not render unclosed blocks as math" do
      expect(PrettyText.cook("$$a\na\n$$\"")).to match_html("<p>$$a<br>\na<br>\n$$\"</p>")
    end

    it "does not render $$ inline within text" do
      expect(PrettyText.cook("test $$a^2$$ test")).to match_html("<p>test $$a^2$$ test</p>")
    end
  end

  describe "LaTeX delimiters" do
    context "when disabled" do
      before { SiteSetting.discourse_math_enable_latex_delimiters = false }

      it "does not render \\(...\\) as math" do
        expect(PrettyText.cook('test \(a^2\) test')).to match_html("<p>test (a^2) test</p>")
      end

      it "does not render \\[...\\] as math" do
        expect(PrettyText.cook("\\[\nx^2\n\\]")).to match_html("<p>[<br>\nx^2<br>\n]</p>")
      end
    end

    context "when enabled" do
      before { SiteSetting.discourse_math_enable_latex_delimiters = true }

      it "renders \\(...\\) as inline math" do
        expect(PrettyText.cook('test \(a^2\) test')).to match_html(
          '<p>test <span class="math">a^2</span> test</p>',
        )
      end

      it "does not render \\(...\\) across multiple lines" do
        expect(PrettyText.cook("test \\(a\nb\\) test")).to match_html("<p>test (a<br>\nb) test</p>")
      end

      it "renders single-line \\[...\\] as block math" do
        expect(PrettyText.cook("\\[x^2 + y^2\\]")).to match_html(
          "<div class=\"math\">\nx^2 + y^2\n</div>",
        )
      end

      it "renders multi-line \\[...\\] as block math" do
        expect(PrettyText.cook("\\[\nx^2\n\\]")).to match_html("<div class=\"math\">\nx^2\n</div>")
      end

      it "does not render \\[...\\] inline within text" do
        expect(PrettyText.cook('test \[a^2\] test')).to match_html("<p>test [a^2] test</p>")
      end
    end
  end

  describe "asciimath with %...%" do
    before { SiteSetting.discourse_math_enable_asciimath = true }

    it "renders asciimath" do
      expect(PrettyText.cook("test %x^2% test")).to match_html(
        '<p>test <span class="asciimath">x^2</span> test</p>',
      )
    end

    it "respects boundary requirements" do
      expect(PrettyText.cook("word%a%")).to match_html("<p>word%a%</p>")
      expect(PrettyText.cook("%a%word")).to match_html("<p>%a%word</p>")
      expect(PrettyText.cook(",%a%,")).to match_html('<p>,<span class="asciimath">a</span>,</p>')
    end
  end
end
