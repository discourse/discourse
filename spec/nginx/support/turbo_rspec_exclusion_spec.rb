# frozen_string_literal: true

require_relative "../../../lib/turbo_rspec_exclusion"

RSpec.describe TurboRspecExclusion do
  describe ".path_for_exclude_match" do
    it "strips bracketed RSpec example ids" do
      expect(described_class.path_for_exclude_match("spec/nginx/basic_proxy_spec.rb[1:1]")).to eq(
        "spec/nginx/basic_proxy_spec.rb",
      )
    end

    it "strips line and bracketed example ids together" do
      expect(
        described_class.path_for_exclude_match("spec/nginx/basic_proxy_spec.rb:42[1:1]"),
      ).to eq("spec/nginx/basic_proxy_spec.rb")
    end
  end

  describe ".excluded_by_patterns?" do
    it "matches bracketed example ids against the nginx exclusion pattern" do
      expect(
        described_class.excluded_by_patterns?(
          "spec/nginx/basic_proxy_spec.rb[1:1]",
          ["spec/nginx/**/*_spec.rb"],
        ),
      ).to eq(true)
    end
  end
end
