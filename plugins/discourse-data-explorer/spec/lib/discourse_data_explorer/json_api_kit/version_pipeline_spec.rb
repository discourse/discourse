# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::VersionPipeline do
  let(:rename_a_to_b) do
    Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
      version "2026-06-01"
      description "Renames a to b on things."

      resource :things do
        up do |resource|
          attributes = resource[:attributes]
          attributes[:b] = attributes.delete(:a) if attributes.key?(:a)
        end
        down do |resource|
          attributes = resource[:attributes]
          attributes[:a] = attributes.delete(:b) if attributes.key?(:b)
        end
      end
    end
  end

  let(:rename_b_to_c) do
    Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
      version "2026-07-01"
      description "Renames b to c on things."

      resource :things do
        up do |resource|
          attributes = resource[:attributes]
          attributes[:c] = attributes.delete(:b) if attributes.key?(:b)
        end
        down do |resource|
          attributes = resource[:attributes]
          attributes[:b] = attributes.delete(:c) if attributes.key?(:c)
        end
      end
    end
  end

  let(:gap) { [rename_b_to_c, rename_a_to_b] }

  describe ".down" do
    subject(:downgraded) { described_class.down(document, gap) }

    context "with an array primary" do
      let(:document) do
        { data: [{ type: :things, attributes: { c: 1 } }, { type: :others, attributes: { c: 9 } }] }
      end

      it "applies the chain newest→oldest to matching resources" do
        expect(downgraded[:data].first[:attributes]).to eq(a: 1)
      end

      it "skips resources of untargeted types" do
        expect(downgraded[:data].last[:attributes]).to eq(c: 9)
      end

      it "returns the same document object" do
        expect(downgraded).to be(document)
      end
    end

    context "with a single-resource primary" do
      let(:document) { { data: { type: :things, attributes: { c: 1 } } } }

      it "applies the chain to the resource" do
        expect(downgraded[:data][:attributes]).to eq(a: 1)
      end
    end

    context "with included resources" do
      let(:document) { { data: [], included: [{ type: :things, attributes: { c: 2 } }] } }

      it "applies the chain to included resources" do
        expect(downgraded[:included].first[:attributes]).to eq(a: 2)
      end
    end

    context "with a document-scope transform" do
      let(:legacy_meta) do
        Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
          version "2026-07-01"
          description "Reintroduces the legacy meta flag."

          document { down { |doc| doc[:meta] = { legacy: true } } }
        end
      end

      let(:gap) { [legacy_meta] }
      let(:document) { { data: [] } }

      it "applies the transform to the document" do
        expect(downgraded[:meta]).to eq(legacy: true)
      end
    end

    context "with an empty gap" do
      let(:gap) { [] }
      let(:document) { { data: [{ type: :things, attributes: { c: 1 } }] } }

      it "returns the document untouched" do
        expect(downgraded[:data].first[:attributes]).to eq(c: 1)
      end
    end

    context "without a data member" do
      let(:document) { { errors: [{ detail: "boom" }] } }

      it "leaves the document intact" do
        expect(downgraded).to eq(errors: [{ detail: "boom" }])
      end
    end
  end

  describe ".up" do
    subject(:upgraded) { described_class.up(document, gap) }

    context "with a single-resource primary (the request-document shape)" do
      let(:document) { { data: { type: "things", attributes: { a: 1 } } } }

      it "applies the chain oldest→newest to the resource" do
        expect(upgraded[:data][:attributes]).to eq(c: 1)
      end

      it "returns the same document object" do
        expect(upgraded).to be(document)
      end
    end

    context "with a resource of an untargeted type" do
      let(:document) { { data: { type: "others", attributes: { a: 9 } } } }

      it "leaves the resource untouched" do
        expect(upgraded[:data][:attributes]).to eq(a: 9)
      end
    end

    context "with hostile input where attributes is not a hash" do
      let(:document) { { data: { type: "things", attributes: "lol" } } }

      it "skips the resource without raising" do
        expect(upgraded[:data][:attributes]).to eq("lol")
      end
    end

    context "with hostile input where data is not a resource object" do
      let(:document) { { data: "lol" } }

      it "leaves the document intact" do
        expect(upgraded).to eq(data: "lol")
      end
    end

    context "with a document-scope transform" do
      let(:drop_legacy_meta) do
        Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
          version "2026-07-01"
          description "Drops the legacy meta flag."

          document { up { |doc| doc.delete(:meta) } }
        end
      end

      let(:gap) { [drop_legacy_meta] }
      let(:document) { { data: { type: "things", attributes: {} }, meta: { legacy: true } } }

      it "applies the transform to the document" do
        expect(upgraded).not_to have_key(:meta)
      end
    end

    context "with an empty gap" do
      let(:gap) { [] }
      let(:document) { { data: { type: "things", attributes: { a: 1 } } } }

      it "returns the document untouched" do
        expect(upgraded[:data][:attributes]).to eq(a: 1)
      end
    end
  end
end
