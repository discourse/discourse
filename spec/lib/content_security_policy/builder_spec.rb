# frozen_string_literal: true
RSpec.describe ContentSecurityPolicy::Builder do
  let(:builder) { described_class.new(base_url: Discourse.base_url) }

  describe "#<<" do
    it "normalizes directive name" do
      builder << {
        :script_src => ["symbol_underscore"],
        :"script-src" => ["symbol_dash"],
        "script_src" => ["string_underscore"],
        "script-src" => ["string_dash"],
      }

      script_srcs = parse(builder.build)["script-src"]

      expect(script_srcs).to include(
        *%w[symbol_underscore symbol_dash string_underscore symbol_underscore],
      )
    end

    it "rejects invalid directives and ones that are not allowed to be extended" do
      builder << { invalid_src: ["invalid"] }

      expect(builder.build).to_not include("invalid")
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

    it "omits nonce when unsafe-inline enabled" do
      builder << { script_src: %w['unsafe-inline' 'nonce-abcde'] }

      expect(builder.build).not_to include("nonce-abcde")
    end

    it "omits sha when unsafe-inline enabled" do
      builder << { script_src: %w['unsafe-inline' 'sha256-abcde'] }

      expect(builder.build).not_to include("sha256-abcde")
    end

    it "keeps sha and nonce when unsafe-inline is not specified" do
      builder << { script_src: %w['nonce-abcde' 'sha256-abcde'] }

      expect(builder.build).to include("nonce-abcde")
      expect(builder.build).to include("sha256-abcde")
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
