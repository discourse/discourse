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
  end
end
