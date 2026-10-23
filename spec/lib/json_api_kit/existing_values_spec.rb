# frozen_string_literal: true

RSpec.describe JsonApiKit::ExistingValues do
  subject(:values) { described_class.for(changes, current:) }

  let(:dimensions) { JsonApiKit::Name::Field.new(value: "dimensions", type: "images") }
  let(:width) { dimensions.with(value: "width") }
  let(:height) { dimensions.with(value: "height") }
  let(:earlier) { Class.new(JsonApiKit::VersionChange).new(__FILE__) }
  let(:later) do
    Class
      .new(JsonApiKit::VersionChange) do
        resource :images do
          split_attribute from: :dimensions,
                          to: %i[width height],
                          up: ->(dimensions) { dimensions },
                          down: ->(width, height) { [width, height] }
        end
      end
      .new(__FILE__)
  end
  let(:changes) { [earlier, later] }
  let(:current) { { width => 640, height => nil } }

  describe "#after" do
    subject(:historical) { values.after(earlier) }

    it "reconstructs the value after that change" do
      expect(historical.fetch(dimensions)).to eq([640, nil])
    end

    context "when a caller changes a returned value" do
      before { historical.fetch(dimensions).clear }

      it "preserves the cached value" do
        expect(historical.fetch(dimensions)).to eq([640, nil])
      end
    end

    context "when a later change converts a value without renaming it" do
      let(:later) do
        Class
          .new(JsonApiKit::VersionChange) do
            resource :images do
              renamed_attribute from: :width,
                                to: :width,
                                up: ->(width) { width * 10 },
                                down: ->(width) { width / 10 }
            end
          end
          .new(__FILE__)
      end

      it "applies the value conversion" do
        expect(historical.fetch(width)).to eq(64)
      end
    end

    context "when a later merge reconstructs several historical members" do
      let(:later) do
        Class
          .new(JsonApiKit::VersionChange) do
            resource :images do
              merged_attributes from: %i[width height],
                                to: :dimensions,
                                up: ->(width, height) { [width, height] },
                                down: ->(dimensions) { dimensions }
            end
          end
          .new(__FILE__)
      end
      let(:current) { { dimensions => [640, 480] } }

      before do
        historical.fetch(width)
        current.fetch(dimensions).replace([800, 600])
      end

      it "retains the other members from the same reconstruction" do
        expect(historical.fetch(height)).to eq(480)
      end
    end
  end
end
