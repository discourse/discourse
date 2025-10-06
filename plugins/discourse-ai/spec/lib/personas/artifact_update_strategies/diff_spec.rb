# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::ArtifactUpdateStrategies::Diff do
  fab!(:user)
  fab!(:post)
  fab!(:artifact, :ai_artifact)
  fab!(:llm_model)

  let(:llm) { llm_model.to_llm }
  let(:instructions) { "Update the button color to red" }

  let(:strategy) do
    described_class.new(
      llm: llm,
      post: post,
      user: user,
      artifact: artifact,
      artifact_version: nil,
      instructions: instructions,
    )
  end

  before { enable_current_plugin }

  describe "#apply" do
    it "processes simple search/replace blocks" do
      original_css = ".button { color: blue; }"
      artifact.update!(css: original_css)

      response = <<~RESPONSE
        [CSS]
        <<<<<<< SEARCH
        .button { color: blue; }
        =======
        .button { color: red; }
        >>>>>>> REPLACE
        [/CSS]
      RESPONSE

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) { strategy.apply }

      expect(artifact.versions.last.css).to eq(".button { color: red; }")
    end

    it "handles multiple search/replace blocks in the same section" do
      original_css = <<~CSS
        .button { color: blue; }
        .text { font-size: 12px; }
      CSS

      artifact.update!(css: original_css)

      response = <<~RESPONSE
        [CSS]
        <<<<<<< SEARCH
        .button { color: blue; }
        =======
        .button { color: red; }
        >>>>>>> REPLACE
        <<<<<<< SEARCH
        .text { font-size: 12px; }
        =======
        .text { font-size: 16px; }
        >>>>>>> REPLACE
        [/CSS]
      RESPONSE

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) { strategy.apply }

      expected = <<~CSS.strip
        .button { color: red; }
        .text { font-size: 16px; }
      CSS

      expect(artifact.versions.last.css.strip).to eq(expected.strip)
    end

    it "handles non-contiguous search/replace using ..." do
      original_css = <<~CSS
        body {
          color: red;
        }
        .button {
          color: blue;
        }
        .alert {
          background-color: green;
        }
      CSS

      artifact.update!(css: original_css)

      response = <<~RESPONSE
        [CSS]
        <<<<<<< SEARCH
        body {
        ...
        background-color: green;
        }
        =======
        body {
          color: red;
        }
        >>>>>>> REPLACE
        [/CSS]
      RESPONSE

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) { strategy.apply }

      expect(artifact.versions.last.css).to eq("body {\n  color: red;\n}")
    end

    it "can handle removal with blank blocks" do
      original_css = <<~CSS
        body {
          color: red;
        }
        .button {
          color: blue;
        }
      CSS

      artifact.update!(css: original_css)

      response = <<~RESPONSE
        [CSS]
        <<<<<<< SEARCH
        body {
          color: red;
        }
        =======
        >>>>>>> REPLACE
        [/CSS]
      RESPONSE

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) { strategy.apply }

      expect(artifact.versions.last.css.strip).to eq(".button {\n  color: blue;\n}")
    end

    it "tracks failed searches" do
      original_css = ".button { color: blue; }"
      artifact.update!(css: original_css)

      response = <<~RESPONSE
        [CSS]
        <<<<<<< SEARCH
        .button { color: green; }
        =======
        .button { color: red; }
        >>>>>>> REPLACE
        [/CSS]
      RESPONSE

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) { strategy.apply }

      expect(strategy.failed_searches).to contain_exactly(
        { section: :css, search: ".button { color: green; }" },
      )
      expect(artifact.versions.last.css).to eq(original_css)
    end

    it "handles complete section replacements" do
      original_html = "<div>old content</div>"
      artifact.update!(html: original_html)

      response = <<~RESPONSE
        [HTML]
        <div>new content</div>
        [/HTML]
      RESPONSE

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) { strategy.apply }

      expect(artifact.versions.last.html.strip).to eq("<div>new content</div>")
    end

    it "ignores empty or 'no changes' sections part 1" do
      original = {
        html: "<div>content</div>",
        css: ".button { color: blue; }",
        js: "console.log('test');",
      }

      artifact.update!(html: original[:html], css: original[:css], js: original[:js])

      response = <<~RESPONSE
        [HTML]
        no changes
        [/HTML]
        [CSS]
        (NO CHANGES)
        [/CSS]
        [JavaScript]
        <<<<<<< SEARCH
        console.log('test');
        =======
        console.log('(no changes)');
        >>>>>>> REPLACE
        [/JavaScript]
      RESPONSE

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) { strategy.apply }

      version = artifact.versions.last
      expect(version.html).to eq(original[:html])
      expect(version.css).to eq(original[:css])
      expect(version.js).to eq("console.log('(no changes)');")
    end

    it "ignores empty or 'no changes' section part 2" do
      original = {
        html: "<div>content</div>",
        css: ".button { color: blue; }",
        js: "console.log('test');",
      }

      artifact.update!(html: original[:html], css: original[:css], js: original[:js])

      response = <<~RESPONSE
        [HTML]
        (no changes)
        [/HTML]
        [CSS]

        [/CSS]
        [JavaScript]
        <<<<<<< SEARCH
        console.log('test');
        =======
        console.log('updated');
        >>>>>>> REPLACE
        [/JavaScript]
      RESPONSE

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) { strategy.apply }

      version = artifact.versions.last
      expect(version.html).to eq(original[:html])
      expect(version.css).to eq(original[:css])
      expect(version.js).to eq("console.log('updated');")
    end
  end
end
