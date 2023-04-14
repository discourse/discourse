# frozen_string_literal: true

require "discourse_sourcemapping_url_processor"

RSpec.describe DiscourseSourcemappingUrlProcessor do
  def process(input)
    env = Sprockets::Environment.new
    env.context_class.class_eval do
      def resolve(path, **kargs)
        "/assets/mapped.js.map"
      end

      def asset_path(path, options = {})
        "/assets/mapped-HEXGOESHERE.js.map"
      end
    end

    input = { environment: env, data: input, name: "mapped", filename: "mapped.js", metadata: {} }
    DiscourseSourcemappingUrlProcessor.call(input)[:data]
  end

  it "maintains relative paths" do
    output = process "var mapped;\n//# sourceMappingURL=mapped.js.map"
    expect(output).to eq("var mapped;\n//# sourceMappingURL=mapped-HEXGOESHERE.js.map\n//!\n")
  end

  it "uses default behaviour for non-adjacent relative paths" do
    output = process "var mapped;\n//# sourceMappingURL=/assets/mapped.js.map"
    expect(output).to eq(
      "var mapped;\n//# sourceMappingURL=/assets/mapped-HEXGOESHERE.js.map\n//!\n",
    )
  end
end
