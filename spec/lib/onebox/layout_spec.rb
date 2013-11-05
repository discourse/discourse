require "spec_helper"

describe Onebox::Layout do
  let(:cache) { Moneta.new(:Memory, expires: true, serializer: :json) }

  describe "#to_html" do
    class OneboxEngineLayout
      include Onebox::Engine

      def data
        "new content"
      end
    end

    it "reads from cache if rendered template is cached" do
      record = {}
      described_class.new("amazon", record, cache).to_html
      expect(cache).to receive(:fetch)
      described_class.new("amazon", record, cache).to_html
    end

    it "stores rendered template if it isn't cached" do
      record = {}
      expect(cache).to receive(:store)
      described_class.new("wikipedia", record, cache).to_html
    end

    it "contains layout template" do
      record = {}
      html = described_class.new("amazon", record, cache).to_html
      expect(html).to include(%|class="onebox|)
    end

    it "contains the view" do
      record = { link: "foo"}
      html = described_class.new("amazon", record, cache).to_html
      expect(html).to include(%|"foo"|)
    end
  end
end
