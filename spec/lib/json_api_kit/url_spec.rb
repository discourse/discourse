# frozen_string_literal: true

RSpec.describe JsonApiKit::Url do
  subject(:url) { described_class.new(address, parameters) }

  let(:address) { "https://example.com/api/topics" }
  let(:parameters) { { "page" => { "size" => "2" }, "sort" => "createdAt" } }

  describe "#to_s" do
    it "returns the address with the parameters it carries" do
      expect(url.to_s).to eq("https://example.com/api/topics?page%5Bsize%5D=2&sort=createdAt")
    end

    context "when it carries no parameter" do
      let(:parameters) { {} }

      it "returns the address on its own" do
        expect(url.to_s).to eq("https://example.com/api/topics")
      end
    end
  end

  describe "#at" do
    context "when the member it adds has several words" do
      let(:parameters) { {} }

      it "writes it in camel case" do
        expect(url.at(before_size: 2).to_s).to eq(
          "https://example.com/api/topics?page%5BbeforeSize%5D=2",
        )
      end
    end

    it "adds the cursor to the parameters it carries" do
      expect(url.at(after: "a-cursor").to_s).to eq(
        "https://example.com/api/topics?page%5Bafter%5D=a-cursor&page%5Bsize%5D=2&sort=createdAt",
      )
    end

    it "leaves this URL unchanged" do
      expect { url.at(after: "a-cursor") }.not_to change { url.to_s }
    end

    context "when it already reads after a cursor" do
      let(:parameters) { { "page" => { "size" => "2", "after" => "read-from-here" } } }

      it "drops the other end" do
        expect(url.at(before: "a-cursor").to_s).to eq(
          "https://example.com/api/topics?page%5Bbefore%5D=a-cursor&page%5Bsize%5D=2",
        )
      end
    end

    context "when it carries a window around an anchor" do
      let(:parameters) do
        {
          "page" => {
            "anchor" => {
              "id" => "12",
            },
            "beforeSize" => "1",
            "afterSize" => "1",
            "includeAnchor" => "false",
            "size" => "2",
          },
        }
      end

      it "drops the anchor and the window, and keeps the page size" do
        expect(url.at(after: "a-cursor").to_s).to eq(
          "https://example.com/api/topics?page%5Bafter%5D=a-cursor&page%5Bsize%5D=2",
        )
      end
    end

    context "when it carries no parameter" do
      let(:parameters) { {} }

      it "carries only that cursor" do
        expect(url.at(after: "a-cursor").to_s).to eq(
          "https://example.com/api/topics?page%5Bafter%5D=a-cursor",
        )
      end
    end
  end
end
