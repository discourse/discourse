# frozen_string_literal: true

RSpec.describe InlineUploads, type: :multisite do
  before { set_cdn_url "https://awesome.com" }

  describe ".process" do
    describe "s3 uploads" do
      let(:upload) { Fabricate(:upload_s3) }
      let(:upload2) { Fabricate(:upload_s3) }
      let(:upload3) { Fabricate(:upload) }

      before do
        upload3
        setup_s3
        SiteSetting.s3_cdn_url = "https://s3.cdn.com"
      end

      it "should correct image URLs in multisite" do
        md = <<~MD
        https:#{upload2.url} https:#{upload2.url}
        #{URI.join(SiteSetting.s3_cdn_url, URI.parse(upload2.url).path)}

        <img src="#{upload.url}" alt="some image">
        <img src="#{URI.join(SiteSetting.s3_cdn_url, URI.parse(upload2.url).path)}" alt="some image">
        <img src="#{upload3.url}">
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        #{Discourse.base_url}#{upload2.short_path} #{Discourse.base_url}#{upload2.short_path}
        #{Discourse.base_url}#{upload2.short_path}

        <img src="#{upload.short_url}" alt="some image">
        <img src="#{upload2.short_url}" alt="some image">
        <img src="#{upload3.short_url}">
        MD
      end
    end
  end
end
