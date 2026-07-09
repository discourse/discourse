# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::VersionChange do
  describe "hand-written transform blocks" do
    subject(:change) do
      Class.new(described_class) do
        version "2026-06-15"
        description "The `foo` attribute of the things resource is renamed to `bar`."

        resource :things do
          up { |resource| resource[:attributes][:bar] = resource[:attributes].delete(:foo) }
          down { |resource| resource[:attributes][:foo] = resource[:attributes].delete(:bar) }
        end

        document do
          down { |document| document[:meta] = (document[:meta] || {}).merge(legacy: true) }
        end
      end
    end

    it "exposes its version as an ApiVersion" do
      expect(change.version).to eq(
        DiscourseDataExplorer::JsonApiKit::ApiVersion.parse("2026-06-15"),
      )
    end

    it "exposes its description" do
      expect(change.description).to include("renamed to `bar`")
    end

    it "cannot be instantiated" do
      expect { change.new }.to raise_error(NoMethodError)
    end

    it "lists the resource types it targets" do
      expect(change.resource_types).to contain_exactly("things")
    end

    describe ".transform_for" do
      context "with the down direction" do
        let(:resource) { { type: :things, attributes: { bar: "x" } } }

        before { change.transform_for(:down, type: "things").call(resource) }

        it "runs the declared down transform" do
          expect(resource[:attributes]).to eq(foo: "x")
        end
      end

      context "with the up direction" do
        let(:resource) { { type: :things, attributes: { foo: "x" } } }

        before { change.transform_for(:up, type: "things").call(resource) }

        it "runs the declared up transform" do
          expect(resource[:attributes]).to eq(bar: "x")
        end
      end

      context "with an untargeted type" do
        it "returns nil" do
          expect(change.transform_for(:down, type: "users")).to be_nil
        end
      end
    end

    describe ".document_transform" do
      context "with a declared direction" do
        let(:document) { { data: [] } }

        before { change.document_transform(:down).call(document) }

        it "runs the declared transform" do
          expect(document[:meta]).to eq(legacy: true)
        end
      end

      context "with an undeclared direction" do
        it "returns nil" do
          expect(change.document_transform(:up)).to be_nil
        end
      end
    end

    it "declares no field renames" do
      expect(change.field_renames_for("things")).to eq({})
    end
  end

  describe "declared renames" do
    subject(:change) do
      Class.new(described_class) do
        version "2026-06-15"
        description "The `foo` attribute of the things resource is renamed to `bar`."

        resource :things do
          renamed_attribute from: :foo, to: :bar
        end
      end
    end

    it "exposes the rename as a field map" do
      expect(change.field_renames_for("things")).to eq(foo: :bar)
    end

    it "exposes an empty field map for an untargeted type" do
      expect(change.field_renames_for("users")).to eq({})
    end

    context "when the resource carries the attribute" do
      let(:resource) { { type: :things, attributes: { foo: "x", other: 1 } } }

      it "up moves the value under the new name" do
        change.transform_for(:up, type: "things").call(resource)

        expect(resource[:attributes]).to eq(bar: "x", other: 1)
      end
    end

    context "when the resource carries the new name" do
      let(:resource) { { type: :things, attributes: { bar: "x" } } }

      it "down moves the value back under the old name" do
        change.transform_for(:down, type: "things").call(resource)

        expect(resource[:attributes]).to eq(foo: "x")
      end
    end

    context "when the attribute is absent" do
      let(:resource) { { type: :things, attributes: { other: 1 } } }

      it "up leaves the resource untouched" do
        change.transform_for(:up, type: "things").call(resource)

        expect(resource[:attributes]).to eq(other: 1)
      end

      it "down leaves the resource untouched" do
        change.transform_for(:down, type: "things").call(resource)

        expect(resource[:attributes]).to eq(other: 1)
      end
    end
  end

  describe "declared renames with value converters" do
    subject(:change) do
      Class.new(described_class) do
        version "2026-07-01"
        description "The `thing` attribute of the things resource becomes a list."

        resource :things do
          renamed_attribute from: :thing,
                            to: :things,
                            up: ->(thing) { [thing] },
                            down: ->(things) { things.first }
        end
      end
    end

    context "when the resource carries the attribute" do
      let(:resource) { { type: :things, attributes: { thing: "x" } } }

      it "up converts the value while renaming" do
        change.transform_for(:up, type: "things").call(resource)

        expect(resource[:attributes]).to eq(things: ["x"])
      end
    end

    context "when the resource carries the new name" do
      let(:resource) { { type: :things, attributes: { things: %w[x y] } } }

      it "down converts the value while renaming" do
        change.transform_for(:down, type: "things").call(resource)

        expect(resource[:attributes]).to eq(thing: "x")
      end
    end

    context "when the attribute is absent" do
      let(:resource) { { type: :things, attributes: { other: 1 } } }

      it "never calls the converters" do
        change.transform_for(:down, type: "things").call(resource)

        expect(resource[:attributes]).to eq(other: 1)
      end
    end
  end

  describe "declared sort and filter renames" do
    subject(:change) do
      Class.new(described_class) do
        version "2026-07-01"
        description "Renames the speed sort and the lookup filter of things."

        resource :things do
          renamed_sort from: :speed, to: :velocity
          renamed_filter from: :lookup, to: :q
        end
      end
    end

    it "exposes the sort renames as a map" do
      expect(change.sort_renames_for("things")).to eq(speed: :velocity)
    end

    it "exposes the filter renames as a map" do
      expect(change.filter_renames_for("things")).to eq(lookup: :q)
    end

    it "exposes empty maps for an untargeted type" do
      expect(change.sort_renames_for("users")).to eq({})
      expect(change.filter_renames_for("users")).to eq({})
    end

    it "does not bleed into the attribute rename map" do
      expect(change.field_renames_for("things")).to eq({})
    end
  end

  describe "declared renames combined with blocks" do
    subject(:change) do
      Class.new(described_class) do
        version "2026-06-15"
        description "Renames foo to bar and records what the block saw."

        resource :things do
          renamed_attribute from: :foo, to: :bar

          up { |resource| resource[:attributes][:seen] = resource[:attributes][:bar] }
          down { |resource| resource[:attributes][:seen] = resource[:attributes][:bar] }
        end
      end
    end

    context "with the up direction" do
      let(:resource) { { type: :things, attributes: { foo: "x" } } }

      it "applies the rename before the block (blocks see the latest vocabulary)" do
        change.transform_for(:up, type: "things").call(resource)

        expect(resource[:attributes]).to eq(bar: "x", seen: "x")
      end
    end

    context "with the down direction" do
      let(:resource) { { type: :things, attributes: { bar: "x" } } }

      it "applies the block before the rename (blocks see the latest vocabulary)" do
        change.transform_for(:down, type: "things").call(resource)

        expect(resource[:attributes]).to eq(foo: "x", seen: "x")
      end
    end
  end
end
