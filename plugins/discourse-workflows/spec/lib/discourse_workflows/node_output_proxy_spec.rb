# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeOutputProxy do
  def run(items:, sources: [], metadata: {})
    { "outputs" => [items], "input_sources" => sources, "metadata" => metadata }
  end

  def source(name, output_index: 0)
    { "node_name" => name, "output_index" => output_index }
  end

  describe "#nearest_upstream_metadata" do
    it "follows item links through conditions and chooses the nearest metadata" do
      upstream = { "id" => 1, "name" => "First" }
      nearest = { "id" => 2, "name" => "Second" }
      context = {
        "__input_sources" => [source("Filter")],
        "__node_runs" => {
          "First" => [run(items: [{ "json" => {} }], metadata: { "review_agent" => upstream })],
          "Second" => [
            run(
              items: [{ "json" => {} }, { "json" => {} }],
              sources: [source("First")],
              metadata: {
                "review_agent" => nearest,
              },
            ),
          ],
          "Filter" => [
            run(
              items: [{ "json" => {}, "pairedItem" => { "item" => 1 } }],
              sources: [source("Second")],
            ),
          ],
        },
      }

      expect(described_class.new(context).nearest_upstream_metadata("review_agent")).to eq(
        [nearest],
      )
    end

    it "keeps multiple contributing sources ambiguous and rejects incomplete or cyclic paths" do
      first = { "id" => 1, "name" => "First" }
      second = { "id" => 2, "name" => "Second" }
      context = {
        "__input_sources" => [source("Merge")],
        "__node_runs" => {
          "First" => [run(items: [{ "json" => {} }], metadata: { "review_agent" => first })],
          "Second" => [run(items: [{ "json" => {} }], metadata: { "review_agent" => second })],
          "Merge" => [
            run(
              items: [
                {
                  "json" => {
                  },
                  "pairedItem" => [{ "input" => 0, "item" => 0 }, { "input" => 1, "item" => 0 }],
                },
              ],
              sources: [source("First"), source("Second")],
            ),
          ],
        },
      }
      proxy = described_class.new(context)
      expect(proxy.nearest_upstream_metadata("review_agent")).to contain_exactly(first, second)

      context["__node_runs"]["Second"].last.delete("metadata")
      context["__node_runs"]["Second"].last["input_sources"] = [source("Missing")]
      expect(proxy.nearest_upstream_metadata("review_agent")).to be_nil

      context["__node_runs"]["Second"] = [
        run(items: [{ "json" => {}, "pairedItem" => { "item" => 0 } }], sources: [source("Merge")]),
      ]
      expect(proxy.nearest_upstream_metadata("review_agent")).to be_nil
    end

    it "returns no attribution for roots and pinned outputs without execution metadata" do
      context = {
        "__input_sources" => [source("Pinned")],
        "__node_runs" => {
          "Pinned" => [run(items: [{ "json" => {} }])],
        },
      }
      expect(described_class.new(context).nearest_upstream_metadata("review_agent")).to eq([])
    end
  end
end
