# frozen_string_literal: true
RSpec.describe ContentSecurityPolicy::Builder do
  let(:builder) { described_class.new(base_url: Discourse.base_url) }

  describe "#<<" do
    it "normalizes directive name" do
      builder << {
        :script_src => ["'symbol_underscore'"],
        :"script-src" => ["'symbol_dash'"],
        "script_src" => ["'string_underscore'"],
        "script-src" => ["'string_dash'"],
      }

      script_srcs = parse(builder.build)["script-src"]

      expect(script_srcs).to include(
        *%w['symbol_underscore' 'symbol_dash' 'string_underscore' 'symbol_underscore'],
      )
    end

    it "rejects invalid directives and ones that are not allowed to be extended" do
      builder << { invalid_src: ["invalid"] }

      expect(builder.build).to_not include("invalid")
    end

    it "skips invalid sources with whitespace or semicolons" do
      invalid_sources = ["invalid source;", "'unsafe-eval' https://invalid.example.com'"]
      builder << { script_src: invalid_sources }
      script_srcs = parse(builder.build)["script-src"]
      invalid_sources.each { |invalid_source| expect(script_srcs).not_to include(invalid_source) }
    end

    it "no-ops on invalid values" do
      previous = builder.build

      builder << nil
      builder << 123
      builder << "string"
      builder << []
      builder << {}

      expect(builder.build).to eq(previous)
    end
  end

  def parse(csp_string)
    csp_string
      .split(";")
      .map do |policy|
        directive, *sources = policy.split
        [directive, sources]
      end
      .to_h
  end
end
