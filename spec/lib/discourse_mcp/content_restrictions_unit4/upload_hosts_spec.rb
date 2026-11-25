# frozen_string_literal: true

require_relative "support"

# Each matrix cell needs an independent baseline receipt.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"
  include UploadsHelpers

  %i[s3 cdn local_cdn].each do |host|
    it "[cr-u4] rejects labeled #{host} upload-host URLs without resolving existence" do
      base =
        if host == :local_cdn
          set_cdn_url "https://u4-local-cdn.example"
          GlobalSetting.cdn_url
        else
          setup_s3
          SiteSetting.s3_cdn_url = "https://u4-upload-cdn.example"
          host == :s3 ? Discourse.store.absolute_base_url : SiteSetting.s3_cdn_url
        end
      raw = "Please inspect [this file](#{base}/original/1X/#{"a" * 40}.png) before replying."
      args = topic_arguments(raw: raw)
      isolated { expect_success(rpc("discourse_create_topic", args)) }
      activate!
      assert_reference_write("discourse_create_topic", args)
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
