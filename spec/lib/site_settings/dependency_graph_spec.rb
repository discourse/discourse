# frozen_string_literal: true

RSpec.describe SiteSettings::DependencyGraph do
  let(:depencency_graph) { described_class.new(dependencies) }

  # Dependency graph:
  #
  # quux       foo
  #            /
  #   qux   bar
  #     \   /
  #      baz
  let(:dependencies) { { foo: [], bar: [:foo], baz: %i[bar qux], qux: [], quux: [] } }

  describe "#order" do
    it "topologically sorts the dependencies" do
      expect(depencency_graph.order).to match_array(%i[foo qux bar baz quux])
    end
  end

  describe "#dependents" do
    it "returns settings that directly depend on the given setting" do
      expect(depencency_graph.dependents(:foo)).to contain_exactly(:bar)
    end

    it "returns multiple dependents when several settings depend on the same one" do
      expect(depencency_graph.dependents(:qux)).to contain_exactly(:baz)
    end

    it "returns an empty array for a setting with no dependents" do
      expect(depencency_graph.dependents(:baz)).to eq([])
    end

    it "returns an empty array for a setting not in the graph" do
      expect(depencency_graph.dependents(:nonexistent)).to eq([])
    end

    context "with a shared dependency" do
      let(:dependencies) { { a: [], b: [:a], c: [:a], d: [:a] } }

      it "returns all settings that depend on the shared dependency" do
        expect(depencency_graph.dependents(:a)).to contain_exactly(:b, :c, :d)
      end
    end

    context "with mixed string and symbol keys (matches real usage)" do
      let(:dependencies) { { enable_foo: [], bar: %w[enable_foo], baz: %w[enable_foo] } }

      it "finds dependents when called with a string" do
        expect(depencency_graph.dependents("enable_foo")).to contain_exactly(:bar, :baz)
      end

      it "finds dependents when called with a symbol" do
        expect(depencency_graph.dependents(:enable_foo)).to contain_exactly(:bar, :baz)
      end
    end
  end
end
