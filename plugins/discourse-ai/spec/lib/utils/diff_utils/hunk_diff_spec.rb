# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::DiffUtils::HunkDiff do
  before { enable_current_plugin }

  describe ".apply_hunk" do
    subject(:apply_hunk) { described_class.apply(original_text, diff) }

    context "with HTML content" do
      let(:original_text) { <<~HTML }
          <div class="container">
            <h1>Original Title</h1>
            <p>Some content here</p>
            <ul>
              <li>Item 1</li>
              <li>Item 2</li>
            </ul>
          </div>
        HTML

      context "when adding content" do
        let(:diff) { <<~DIFF }
            <div class="container">
              <h1>Original Title</h1>
            +  <h2>New Subtitle</h2>
              <p>Some content here</p>
          DIFF

        it "inserts the new content" do
          expected = <<~HTML
            <div class="container">
              <h1>Original Title</h1>
              <h2>New Subtitle</h2>
              <p>Some content here</p>
              <ul>
                <li>Item 1</li>
                <li>Item 2</li>
              </ul>
            </div>
          HTML
          expect(apply_hunk).to eq(expected.strip)
        end
      end

      context "when removing content" do
        let(:diff) { <<~DIFF }
            <ul>
            - <li>Item 1</li>
            <li>Item 2</li>
          DIFF

        it "removes the specified content" do
          # note how this is super forgiving
          expected = <<~HTML
            <div class="container">
              <h1>Original Title</h1>
              <p>Some content here</p>
              <ul>
                <li>Item 2</li>
              </ul>
            </div>
          HTML
          expect(apply_hunk).to eq(expected.strip)
        end
      end

      context "when replacing content" do
        let(:diff) { <<~DIFF }
             <div class="container">
            -  <h1>Original Title</h1>
            +  <h1>Updated Title</h1>
               <p>Some content here</p>
          DIFF

        it "replaces the content correctly" do
          expected = <<~HTML
            <div class="container">
              <h1>Updated Title</h1>
              <p>Some content here</p>
              <ul>
                <li>Item 1</li>
                <li>Item 2</li>
              </ul>
            </div>
          HTML

          expect(apply_hunk).to eq(expected.strip)
        end
      end
    end

    context "with CSS content" do
      let(:original_text) { <<~CSS }
          .container {
            background: #fff;
            padding: 20px;
            margin: 10px;
          }
        CSS

      context "when modifying properties" do
        let(:diff) { <<~DIFF }
             .container {
            -  background: #fff;
            +  background: #f5f5f5;
            +  happy: sam;
            -  padding: 20px;
            +  padding: 10px;
          DIFF

        it "updates the property value" do
          expected = <<~CSS
            .container {
              background: #f5f5f5;
              happy: sam;
              padding: 10px;
              margin: 10px;
            }
          CSS

          expect(apply_hunk).to eq(expected.strip)
        end
      end
    end

    context "when handling errors" do
      let(:original_text) { <<~HTML }
          <div>
            <h1>Title</h1>
            <p>
            <h1>Title</h1>
            <p>
          </div>
        HTML

      context "with ambiguous matches" do
        let(:diff) { <<~DIFF }
             <h1>Title</h1>
            +<h2>Subtitle</h2>
             <p>
          DIFF

        it "raises an AmbiguousMatchError" do
          expect { apply_hunk }.to raise_error(
            DiscourseAi::Utils::DiffUtils::HunkDiff::AmbiguousMatchError,
          ) do |error|
            expect(error.to_llm_message).to include("Found multiple possible locations")
          end
        end
      end

      context "with no matching context" do
        let(:diff) { <<~DIFF }
             <h1>Wrong Title</h1>
            +<h2>Subtitle</h2>
             <p>
          DIFF

        it "raises a NoMatchingContextError" do
          expect { apply_hunk }.to raise_error(
            DiscourseAi::Utils::DiffUtils::HunkDiff::NoMatchingContextError,
          ) do |error|
            expect(error.to_llm_message).to include("Could not find the context lines")
          end
        end
      end

      context "with malformed diffs" do
        context "when empty" do
          let(:diff) { "" }

          it "raises a MalformedDiffError" do
            expect { apply_hunk }.to raise_error(
              DiscourseAi::Utils::DiffUtils::HunkDiff::MalformedDiffError,
            ) do |error|
              expect(error.context["Issue"]).to eq("Diff is empty")
            end
          end
        end
      end
    end

    context "without markers" do
      let(:original_text) { "hello" }
      let(:diff) { "world" }
      it "will append to the end" do
        expect(apply_hunk).to eq("hello\nworld")
      end
    end

    context "when appending text to the end of a document" do
      let(:original_text) { "hello\nworld" }

      let(:diff) { <<~DIFF }
          world
          +123
        DIFF

      it "can append to end" do
        expect(apply_hunk).to eq("hello\nworld\n123")
      end
    end

    context "when applying multiple hunks to a file" do
      let(:original_text) { <<~TEXT }
          1
          2
          3
          4
          5
          6
          7
          8
        TEXT

      let(:diff) { <<~DIFF }
          @@ -1,4 +1,4 @@
          2
          - 3
          @@ -6,4 +6,4 @@
          - 7
        DIFF

      it "can apply multiple hunks" do
        expected = <<~TEXT
          1
          2
          4
          5
          6
          8
        TEXT
        expect(apply_hunk).to eq(expected.strip)
      end
    end

    context "with line ending variations" do
      let(:original_text) { "line1\r\nline2\nline3\r\n" }
      let(:diff) { <<~DIFF }
           line1
          +new line
           line2
        DIFF

      it "handles mixed line endings" do
        expect(apply_hunk).to include("new line")
        expect(apply_hunk.lines.count).to eq(4)
      end
    end

    context "with whitespace sensitivity" do
      let(:original_text) { <<~TEXT }
          def method
              puts "hello"
          end
        TEXT

      context "when indentation matters" do
        let(:diff) { <<~DIFF }
             def method
            -    puts "hello"
            +    puts "world"
               end
          DIFF

        it "preserves exact indentation" do
          result = apply_hunk
          expect(result).to match(/^    puts "world"$/)
        end
      end

      context "when trailing whitespace exists" do
        let(:original_text) { "line1  \nline2\n" }
        let(:diff) { <<~DIFF }
             line1
            +new line
             line2
          DIFF

        it "preserves significant whitespace" do
          expect(apply_hunk).to include("line1  \n")
        end
      end
    end
  end
end
