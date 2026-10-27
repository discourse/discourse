# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Body::Attributes do
  subject(:input) { described_class.new(document, glossary:, existing:) }

  let(:document) { { "data" => { "type" => "topics", "attributes" => attributes } } }
  let(:attributes) { { "createdAt" => "2026-09-01", "settings" => { "keepCase" => [nil, "12"] } } }
  let(:glossary) { JsonApiKit::Edition.new(changes).glossary }
  let(:changes) { [] }
  let(:existing) { JsonApiKit::ExistingValues::None }

  describe "#parameters" do
    it "uses declared names for parameter keys" do
      expect(input.parameters).to eq(
        created_at: "2026-09-01",
        settings: {
          "keepCase" => [nil, "12"],
        },
      )
    end

    context "when the glossary raises an unexpected argument error" do
      before do
        allow(glossary).to receive(:declared_attributes).and_raise(
          ArgumentError,
          "Unexpected error",
        )
      end

      it "preserves the exception" do
        expect { input.parameters }.to raise_error(ArgumentError, "Unexpected error")
      end
    end

    context "when a converter mutates its input" do
      let(:attributes) { { "words" => %w[Hello world] } }
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource :topics do
                renamed_attribute from: :words,
                                  to: :title,
                                  up: ->(words) { words.reverse!.join(" ") },
                                  down: ->(title) { title.split(" ") }
              end
            end
            .new(__FILE__),
        ]
      end

      before { input.parameters }

      it "preserves the submitted document" do
        expect(document.dig("data", "attributes", "words")).to eq(%w[Hello world])
      end
    end

    context "when existing values complete a partial merge" do
      let(:attributes) { { "width" => 800 } }
      let(:dimensions) { JsonApiKit::Name::Field.new(value: "dimensions", type: "topics") }
      let(:existing) do
        JsonApiKit::ExistingValues.for(changes, current: { dimensions => [640, 480] })
      end
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource :topics do
                merged_attributes from: %i[width height],
                                  to: :dimensions,
                                  up: ->(width, height) { [width, height] },
                                  down: ->(dimensions) { dimensions }
              end
            end
            .new(__FILE__),
        ]
      end

      it "supplies the completed value" do
        expect(input.parameters).to eq(dimensions: [800, 480])
      end

      it "keeps recovered values out of the submitted locations" do
        expect(input.locations_for(:dimensions).map(&:pointer)).to contain_exactly(
          "/data/attributes/width",
        )
      end

      context "when the existing value has an invalid converter result" do
        let(:existing) { JsonApiKit::ExistingValues.for(changes, current: { dimensions => [640] }) }

        it "preserves the existing-state failure" do
          expect { input.parameters }.to raise_error(ArgumentError, /down converter for dimensions/)
        end
      end
    end
  end

  describe "#locations_for" do
    subject(:pointers) { input.locations_for(parameter).map(&:pointer) }

    let(:attributes) { { "width" => 640, "height" => 480, "size" => [320, 240] } }
    let(:parameter) { :dimensions }
    let(:changes) do
      [
        Class
          .new(JsonApiKit::VersionChange) do
            resource :topics do
              merged_attributes from: %i[width height],
                                to: :dimensions,
                                up: ->(width, height) { [width, height] },
                                down: ->(dimensions) { dimensions }
              split_attribute from: :size,
                              to: %i[pixel_width pixel_height],
                              up: ->(size) { size },
                              down: ->(width, height) { [width, height] }
            end
          end
          .new(__FILE__),
      ]
    end

    it "retains every supplied merge source" do
      expect(pointers).to contain_exactly("/data/attributes/width", "/data/attributes/height")
    end

    context "when a merge source is omitted" do
      let(:attributes) { super().except("height") }

      it "retains only the supplied location" do
        expect(pointers).to contain_exactly("/data/attributes/width")
      end
    end

    context "when an attribute is split" do
      let(:parameter) { :pixel_height }

      it "retains the original source location" do
        expect(pointers).to contain_exactly("/data/attributes/size")
      end
    end

    context "when a parameter was not supplied" do
      let(:parameter) { :title }

      it { is_expected.to be_empty }
    end

    context "when a submitted name has the wrong casing" do
      let(:attributes) { { "bad_name" => 12 } }

      it "reports a body error at the submitted location" do
        expect { pointers }.to raise_error(JsonApiKit::Request::Body::ConversionError) do |error|
          expect(error.source).to eq(pointer: "/data/attributes/bad_name")
        end
      end
    end

    context "when a submitted name belongs to a later version" do
      let(:attributes) { { "dimensions" => [640, 480] } }

      it "reports a body error at the submitted location" do
        expect { pointers }.to raise_error(JsonApiKit::Request::Body::ConversionError) do |error|
          expect(error.source).to eq(pointer: "/data/attributes/dimensions")
        end
      end
    end

    context "when the value cannot be converted" do
      let(:attributes) { { "size" => nil } }
      let(:parameter) { :pixel_height }

      it "locates the member without converting its value" do
        expect(pointers).to contain_exactly("/data/attributes/size")
      end
    end

    context "when a later change merges the split destinations" do
      let(:parameter) { :resolution }
      let(:changes) do
        super() +
          [
            Class
              .new(JsonApiKit::VersionChange) do
                resource :topics do
                  merged_attributes from: %i[pixel_width pixel_height],
                                    to: :resolution,
                                    up: ->(width, height) { [width, height] },
                                    down: ->(resolution) { resolution }
                end
              end
              .new(__FILE__),
          ]
      end

      it "retains the original location once" do
        expect(pointers).to contain_exactly("/data/attributes/size")
      end
    end
  end
end
