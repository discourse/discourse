# frozen_string_literal: true

RSpec.describe Migrations::ClassFilter do
  def test_class(name:, dependencies: nil)
    Class.new do
      define_singleton_method(:name) { name }
      define_singleton_method(:dependencies) { dependencies } unless dependencies.nil?
    end
  end

  let(:users) { test_class(name: "Steps::Users") }
  let(:topics) { test_class(name: "Steps::Topics") }
  let(:topic_users) { test_class(name: "Steps::TopicUsers", dependencies: [topics, users]) }

  # Dependencies first, like the already sorted lists callers pass in.
  let(:classes) { [topics, users, topic_users] }

  describe ".filter" do
    it "returns all classes when no filters are given" do
      expect(described_class.filter(classes)).to eq(classes)
    end

    it "selects only the named classes" do
      expect(described_class.filter(classes, only: ["topics"])).to eq([topics])
    end

    it "rejects the skipped classes" do
      expect(described_class.filter(classes, skip: ["topics"])).to eq([users, topic_users])
    end

    it "raises an error for unknown class names" do
      expect { described_class.filter(classes, only: ["missing"]) }.to raise_error(
        Migrations::ClassFilter::UnknownClassNamesError,
        "Unknown class names: missing",
      )
    end

    it "pulls in the dependencies of selected classes" do
      result = described_class.filter(classes, only: ["topic_users"])

      expect(result).to contain_exactly(topics, users, topic_users)
    end

    it "doesn't pull in dependencies that are explicitly skipped" do
      result = described_class.filter(classes, only: ["topic_users"], skip: ["users"])

      expect(result).to eq([topics, topic_users])
    end

    it "preserves the input order when dependencies are pulled in" do
      # The converter executes the filtered list as-is, so a dependency pulled
      # in by `only` has to come before the class that depends on it.
      result = described_class.filter(classes, only: ["topic_users"])

      expect(result).to eq([topics, users, topic_users])
    end

    it "preserves the input order of transitive dependencies" do
      base = test_class(name: "Steps::Base")
      middle = test_class(name: "Steps::Middle", dependencies: [base])
      top = test_class(name: "Steps::Top", dependencies: [middle])

      result = described_class.filter([base, middle, top], only: ["top"])

      expect(result).to eq([base, middle, top])
    end

    it "raises for unknown names given via skip" do
      expect { described_class.filter(classes, skip: ["missing"]) }.to raise_error(
        Migrations::ClassFilter::UnknownClassNamesError,
        "Unknown class names: missing",
      )
    end

    it "reports an unknown name once when it is given in both skip and only" do
      expect {
        described_class.filter(classes, only: ["missing"], skip: ["missing"])
      }.to raise_error(
        Migrations::ClassFilter::UnknownClassNamesError,
        "Unknown class names: missing",
      )
    end

    it "ignores a class whose dependencies are nil" do
      no_deps =
        Class.new do
          define_singleton_method(:name) { "Steps::NoDeps" }
          define_singleton_method(:dependencies) { nil }
        end

      expect(described_class.filter([no_deps], only: ["no_deps"])).to eq([no_deps])
    end

    it "ignores dependencies that are not part of the class list" do
      external = test_class(name: "Steps::External")
      parent = test_class(name: "Steps::Parent", dependencies: [external])

      expect(described_class.filter([parent], only: ["parent"])).to eq([parent])
    end

    it "terminates when dependencies form a cycle" do
      first = test_class(name: "Steps::First")
      second = test_class(name: "Steps::Second", dependencies: [first])
      first.define_singleton_method(:dependencies) { [second] }

      result = described_class.filter([first, second], only: ["first"])

      expect(result).to contain_exactly(first, second)
    end

    it "keeps scanning dependencies after one is already included" do
      shared = test_class(name: "Steps::Shared")
      extra = test_class(name: "Steps::Extra")
      parent = test_class(name: "Steps::WithShared", dependencies: [shared, extra])

      result = described_class.filter([shared, extra, parent], only: %w[with_shared shared])

      expect(result).to contain_exactly(shared, extra, parent)
    end

    it "keeps scanning dependencies after skipping one" do
      skipped = test_class(name: "Steps::Skipped")
      kept = test_class(name: "Steps::Kept")
      parent = test_class(name: "Steps::WithSkipped", dependencies: [skipped, kept])

      result =
        described_class.filter(
          [skipped, kept, parent],
          only: ["with_skipped"],
          skip: ["skipped"],
        )

      expect(result).to contain_exactly(kept, parent)
    end

    it "applies default filters when instantiated without skip or only" do
      expect(described_class.new(classes).filter).to eq(classes)
    end
  end
end
