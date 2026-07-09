# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::VersionPipeline do
  let(:rename_a_to_b) do
    Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
      version "2026-06-01"
      description "Renames a to b on things."

      resource :things do
        renamed_attribute from: :a, to: :b
      end
    end
  end

  let(:rename_b_to_c) do
    Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
      version "2026-07-01"
      description "Renames b to c on things."

      resource :things do
        renamed_attribute from: :b, to: :c
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

  describe ".up_fieldset" do
    subject(:upgraded) { described_class.up_fieldset(names, type: :things, changes: gap) }

    context "when fields name renamed attributes" do
      let(:names) { %w[name a] }

      it "maps the old names through the whole chain" do
        expect(upgraded).to eq(%i[name c])
      end
    end

    context "with an empty gap" do
      let(:gap) { [] }
      let(:names) { %w[name a] }

      it "returns the names as given" do
        expect(upgraded).to eq(%i[name a])
      end
    end

    context "when a rename declares value converters (shape change)" do
      let(:shape_change) do
        Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
          version "2026-07-01"
          description "The thing becomes a list of things."

          resource :things do
            renamed_attribute from: :thing,
                              to: :things,
                              up: ->(thing) { [thing] },
                              down: ->(things) { things.first }
          end
        end
      end

      let(:gap) { [shape_change] }
      let(:names) { %w[thing] }

      it "maps the name exactly without running the converters" do
        expect(upgraded).to eq(%i[things])
      end
    end

    context "when a change only has hand-written blocks" do
      let(:block_only) do
        Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
          version "2026-07-01"
          description "Merges the parts into a whole, without declaring it."

          resource :things do
            up do |resource|
              attributes = resource[:attributes]
              attributes[:whole] = attributes.delete(:parts).join(" ") if attributes.key?(:parts)
            end
          end
        end
      end

      let(:gap) { [block_only] }
      let(:names) { %w[parts] }

      it "leaves the names unchanged without running any transform" do
        expect(upgraded).to eq(%i[parts])
      end
    end
  end

  describe ".down_errors" do
    subject(:downgraded) { described_class.down_errors(document, type: :things, changes: gap) }

    context "when a pointer targets a renamed attribute" do
      let(:document) { { errors: [{ status: "422", source: { pointer: "/data/attributes/c" } }] } }

      it "rewrites the pointer through the whole chain" do
        expect(downgraded[:errors].first.dig(:source, :pointer)).to eq("/data/attributes/a")
      end
    end

    context "when a pointer targets an untouched attribute" do
      let(:document) do
        { errors: [{ status: "422", source: { pointer: "/data/attributes/name" } }] }
      end

      it "keeps the pointer" do
        expect(downgraded[:errors].first.dig(:source, :pointer)).to eq("/data/attributes/name")
      end
    end

    context "when an error has no source pointer" do
      let(:document) { { errors: [{ status: "422", detail: "boom" }] } }

      it "leaves the error intact" do
        expect(downgraded[:errors].first).to eq(status: "422", detail: "boom")
      end
    end

    context "when a pointer targets something other than an attribute" do
      let(:document) do
        { errors: [{ status: "422", source: { pointer: "/data/relationships/groups" } }] }
      end

      it "keeps the pointer" do
        expect(downgraded[:errors].first.dig(:source, :pointer)).to eq("/data/relationships/groups")
      end
    end

    context "with an empty gap" do
      let(:gap) { [] }
      let(:document) { { errors: [{ status: "422", source: { pointer: "/data/attributes/c" } }] } }

      it "returns the document untouched" do
        expect(downgraded[:errors].first.dig(:source, :pointer)).to eq("/data/attributes/c")
      end
    end

    context "when the rename declares value converters (shape change)" do
      let(:shape_change) do
        Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
          version "2026-07-01"
          description "The thing becomes a list of things."

          resource :things do
            renamed_attribute from: :thing,
                              to: :things,
                              up: ->(thing) { [thing] },
                              down: ->(things) { things.first }
          end
        end
      end

      let(:gap) { [shape_change] }
      let(:document) do
        { errors: [{ status: "422", source: { pointer: "/data/attributes/things" } }] }
      end

      it "rewrites the pointer exactly without running the converters" do
        expect(downgraded[:errors].first.dig(:source, :pointer)).to eq("/data/attributes/thing")
      end
    end

    context "when a change only has hand-written blocks" do
      let(:block_only) do
        Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
          version "2026-07-01"
          description "Replaces the single thing with a list, without declaring it."

          resource :things do
            down do |resource|
              attributes = resource[:attributes]
              attributes[:thing] = attributes.delete(:things).first if attributes.key?(:things)
            end
          end
        end
      end

      let(:gap) { [block_only] }
      let(:document) do
        { errors: [{ status: "422", source: { pointer: "/data/attributes/things" } }] }
      end

      it "keeps the latest pointer without running any transform" do
        expect(downgraded[:errors].first.dig(:source, :pointer)).to eq("/data/attributes/things")
      end
    end
  end
end
