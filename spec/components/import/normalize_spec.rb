require "rails_helper"
require_dependency "import/normalize"

describe Import::Normalize do
  describe "#normalize_code_blocks" do
    it "normalizes 2 code blocks correctly" do
      markdown = <<MD
      &nbsp;
      <pre>
        <code>
        I am a te&nbsp;&quot;
        </code></pre>
        test &nbsp;
        <pre><code>this is a &quot;&quot;</code></pre>
MD
      expected = "      &nbsp;\n      \n```\n        I am a te \"\n        \n```\n\n        test &nbsp;\n        \n```\nthis is a \"\"\n```\n\n"
      expect(Import::Normalize.normalize_code_blocks(markdown)).to eq(expected)
    end
  end
end
