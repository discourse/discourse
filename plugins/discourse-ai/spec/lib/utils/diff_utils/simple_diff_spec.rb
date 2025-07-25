# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::DiffUtils::SimpleDiff do
  subject(:simple_diff) { described_class }

  before { enable_current_plugin }

  describe ".apply" do
    it "raises error for nil inputs" do
      expect { simple_diff.apply(nil, "search", "replace") }.to raise_error(ArgumentError)
      expect { simple_diff.apply("content", nil, "replace") }.to raise_error(ArgumentError)
      expect { simple_diff.apply("content", "search", nil) }.to raise_error(ArgumentError)
    end

    it "prioritizes exact matches over all fuzzy matches" do
      content = <<~TEXT
        line 1
          line 1
        lin 1
      TEXT

      search = "  line 1"
      replace = "  new_line"
      expected = <<~TEXT
        line 1
          new_line
        lin 1
      TEXT

      expect(simple_diff.apply(content, search, replace).strip).to eq(expected.strip)
    end

    it "raises error when no match is found" do
      content = "line1\ncompletely_different\nline3"
      search = "nothing_like_this"
      replace = "new_line"
      expect { simple_diff.apply(content, search, replace) }.to raise_error(
        DiscourseAi::Utils::DiffUtils::SimpleDiff::NoMatchError,
      )
    end

    it "replaces all matching occurrences" do
      content = "line1\nline2\nmiddle\nline2\nend"
      search = "line2"
      replace = "new_line2"
      expect(simple_diff.apply(content, search, replace)).to eq(
        "line1\nnew_line2\nmiddle\nnew_line2\nend",
      )
    end

    it "replaces exact matches" do
      content = "line1\nline2\nline3"
      search = "line2"
      replace = "new_line2"
      expect(simple_diff.apply(content, search, replace)).to eq("line1\nnew_line2\nline3")
    end

    it "handles multi-line replacements" do
      content = "start\nline1\nline2\nend"
      search = "line1\nline2"
      replace = "new_line"
      expect(simple_diff.apply(content, search, replace)).to eq("start\nnew_line\nend")
    end

    it "is forgiving of whitespace differences" do
      content = "line1\n line2\nline3"
      search = "line2"
      replace = "new_line2"
      expect(simple_diff.apply(content, search, replace).strip).to eq("line1\n new_line2\nline3")
    end

    it "is forgiving of small character differences" do
      content = "line one one one\nlin2\nline three three" # Notice 'lin2' instead of 'line2'
      search = "line2"
      replace = "new_line2"
      expect(simple_diff.apply(content, search, replace)).to eq(
        "line one one one\nnew_line2\nline three three",
      )
    end

    it "is forgiving in multi-line blocks with indentation differences" do
      content = "def method\n    line1\n  line2\nend"
      search = "line1\nline2"
      replace = "new_content"
      expect(simple_diff.apply(content, search, replace)).to eq("def method\nnew_content\nend")
    end

    it "handles CSS blocks in different orders" do
      content = <<~CSS
        .first {
          color: red;
          padding: 10px;
        }
        .second {
          color: blue;
          margin: 20px;
        }
      CSS

      search = <<~CSS
        .second {
          color: blue;
          margin: 20px;
        }
        .first {
          color: red;
          padding: 10px;
        }
      CSS

      replace = <<~CSS
        .new-block {
          color: green;
        }
      CSS

      expected = <<~CSS
        .new-block {
          color: green;
        }
      CSS

      expect(simple_diff.apply(content, search, replace)).to eq(expected.strip)
    end

    it "handles partial line matches" do
      content = "abc hello efg\nabc hello efg"
      search = "hello"
      replace = "bob"
      expect(simple_diff.apply(content, search, replace)).to eq("abc bob efg\nabc bob efg")
    end

    it "handles JavaScript blocks in different orders" do
      content = <<~JS
        function first() {
          const x = 1;
          return x + 2;
        }

        function second() {
          if (true) {
            return 42;
          }
          return 0;
        }
      JS

      search = <<~JS
        function second() {
          if (true) {
            return 42;
          }
          return 0;
        }

        function first() {
          const x = 1;
          return x + 2;
        }
      JS

      replace = <<~JS
        function replacement() {
          return 'new';
        }
      JS

      expected = <<~JS
        function replacement() {
          return 'new';
        }
      JS

      expect(simple_diff.apply(content, search, replace).strip).to eq(expected.strip)
    end

    it "handles missing lines in search" do
      original = <<~TEXT
        line1
         line2
        line3
        line4
        line5
        line1
        line2
      TEXT

      search = <<~TEXT
        line1
        ...
         line3
        ...
        line1
      TEXT

      replace = ""

      expected = <<~TEXT
        line2
      TEXT

      expect(simple_diff.apply(original, search, replace).strip).to eq(expected.strip)
    end
  end
end
