# frozen_string_literal: true

RSpec.describe SiteSettings::DependencyGraph do
  let(:depencency_graph) { described_class.new(dependencies) }

  describe "#order" do
    # Dependency graph:
    #
    # quux       foo
    #            /
    #   qux   bar
    #     \   /
    #      baz
    let(:dependencies) { { foo: [], bar: [:foo], baz: %i[bar qux], qux: [], quux: [] } }

    it "topologically sorts the dependencies" do
      expect(depencency_graph.order).to match_array(%i[foo qux bar baz quux])
    end
  end
end
