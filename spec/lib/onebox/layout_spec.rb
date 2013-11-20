require "spec_helper"

describe Onebox::Layout do
  let(:cache) { Moneta.new(:Memory, expires: true, serializer: :json) }
  let(:record) { {} }
  let(:onebox) { described_class.new("amazon", record, cache) }
  let(:html) { onebox.to_html }

  describe ".template_path" do
    before(:each) do
      Onebox.options.load_paths << "directory_b"
      Onebox.options.load_paths << "directory_c"
    end

    let(:template_path) { onebox.template_path }

    it "looks in directory C for template" do
      allow(described_class).to receive(:valid_load_path?) do |path|
        path == "directory_c"
      end
      expect(template_path).to eq("directory_c")
    end

    it "looks in directory B if template doesn't exist in C" do
      allow(described_class).to receive(:valid_load_path?) do |path|
        path == "directory_b"
      end
      expect(template_path).to eq("directory_b")
    end

    it "looks in default directory if template doesn't exist in B or C" do
      expect(template_path).to include("template")
    end

    after(:each) do
      Onebox.options.load_paths.pop(2)
    end
  end

  describe "#to_html" do
    class OneboxEngineLayout
      include Onebox::Engine

      def data
        "new content"
      end
    end

    it "reads from cache if rendered template is cached" do
      described_class.new("amazon", record, cache).to_html
      expect(cache).to receive(:fetch)
      described_class.new("amazon", record, cache).to_html
    end

    it "stores rendered template if it isn't cached" do
      expect(cache).to receive(:store)
      described_class.new("wikipedia", record, cache).to_html
    end

    it "contains layout template" do
      expect(html).to include(%|class="onebox|)
    end

    it "contains the view" do
      record = { link: "foo" }
      html = described_class.new("amazon", record, cache).to_html
      expect(html).to include(%|"foo"|)
    end
  end
end
