require "spec_helper"

describe Onebox::Layout do
  let(:cache) { Moneta.new(:Memory, expires: true, serializer: :json) }
  let(:record) { {} }
  let(:onebox) { described_class.new("amazon", record, cache) }
  let(:html) { onebox.to_html }

  describe ".template_path" do
    let(:template_path) { onebox.template_path }

    before(:each) do
      Onebox.options.load_paths << "directory_a"
      Onebox.options.load_paths << "directory_b"
    end

    context "when template exists in directory_b" do
      before(:each) do
        allow_any_instance_of(described_class).to receive(:template?) { |_,path| path == "directory_b" }
      end

      it "returns directory_b" do
        expect(template_path).to eq("directory_b")
      end
    end

    context "when template exists in directory_a" do
      before(:each) do
        allow_any_instance_of(described_class).to receive(:template?) { |_,path| path == "directory_a" }
      end

      it "returns directory_a" do
        expect(template_path).to eq("directory_a")
      end
    end

    context "when template doesn't exist in directory_a or directory_b" do
      it "returns default path" do
        expect(template_path).to include("template")
      end
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
