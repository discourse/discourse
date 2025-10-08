# frozen_string_literal: true

RSpec.describe ::Migrations::TopologicalSorter do
  def test_class(name:, priority: nil, dependencies: nil)
    Class.new do
      define_singleton_method(:name) { name }
      define_singleton_method(:to_s) { name }
      define_singleton_method(:priority) { priority } if priority
      define_singleton_method(:dependencies) { dependencies } unless dependencies.nil?
    end
  end

  def sorted_names(result)
    result.map(&:name)
  end

  describe ".sort" do
    it "delegates to instance method" do
      klass = test_class(name: "Class1")
      sorter = instance_double(described_class)
      allow(described_class).to receive(:new).with([klass]).and_return(sorter)
      allow(sorter).to receive(:sort).and_return([])

      described_class.sort([klass])

      expect(sorter).to have_received(:sort)
    end
  end

  describe "#sort" do
    context "with no dependencies" do
      it "returns classes sorted by priority and name" do
        class1 = test_class(name: "Class1", priority: 2)
        class2 = test_class(name: "Class2", priority: 1)

        result = described_class.sort([class1, class2])

        expect(sorted_names(result)).to eq(%w[Class2 Class1])
      end

      it "sorts classes without priority by name" do
        z_class = test_class(name: "ZClass")
        a_class = test_class(name: "AClass")

        result = described_class.sort([z_class, a_class])

        expect(sorted_names(result)).to eq(%w[AClass ZClass])
      end

      it "prioritizes classes with priority over those without" do
        a_class = test_class(name: "AClass")
        z_class = test_class(name: "ZClass", priority: 5)

        result = described_class.sort([a_class, z_class])

        expect(sorted_names(result)).to eq(%w[ZClass AClass])
      end
    end

    context "with simple dependencies" do
      it "sorts classes based on dependencies then priority and name" do
        class2 = test_class(name: "Class2", priority: 2)
        class1 = test_class(name: "Class1", priority: 1, dependencies: [class2])

        result = described_class.sort([class1, class2])

        expect(sorted_names(result)).to eq(%w[Class2 Class1])
      end
    end

    context "with multiple classes at same dependency level" do
      it "sorts by priority then name within same level" do
        dependency = test_class(name: "Dependency", priority: 1)
        class1 = test_class(name: "Class1", priority: 3, dependencies: [dependency])
        class2 = test_class(name: "Class2", priority: 1, dependencies: [dependency])
        class3 = test_class(name: "ZClass", dependencies: [dependency])
        class4 = test_class(name: "AClass", dependencies: [dependency])

        result = described_class.sort([class1, class2, class3, class4, dependency])

        expect(sorted_names(result)).to eq(%w[Dependency Class2 Class1 AClass ZClass])
      end
    end

    context "with chain dependencies" do
      it "sorts classes in correct order" do
        class3 = test_class(name: "Class3")
        class2 = test_class(name: "Class2", dependencies: [class3])
        class1 = test_class(name: "Class1", dependencies: [class2])

        result = described_class.sort([class1, class2, class3])

        expect(sorted_names(result)).to eq(%w[Class3 Class2 Class1])
      end
    end

    context "with external dependencies" do
      it "raises TopologicalSorterError for missing dependencies" do
        external_class = test_class(name: "External")
        class1 = test_class(name: "Class1", dependencies: [external_class])

        expect { described_class.sort([class1]) }.to raise_error(
          Migrations::TopologicalSorterError,
          "Node 'Class1' has dependencies not in class list: External",
        )
      end
    end

    context "with circular dependencies" do
      it "raises TopologicalSorterError" do
        class1 = test_class(name: "Class1")
        class2 = test_class(name: "Class2")
        class1.define_singleton_method(:dependencies) { [class2] }
        class2.define_singleton_method(:dependencies) { [class1] }

        expect { described_class.sort([class1, class2]) }.to raise_error(
          Migrations::TopologicalSorterError,
          "Circular dependency detected",
        )
      end
    end

    context "with empty dependencies array" do
      it "treats as no dependencies" do
        class1 = test_class(name: "Class1", dependencies: [])

        result = described_class.sort([class1])

        expect(sorted_names(result)).to eq(["Class1"])
      end
    end

    context "with nil dependencies" do
      it "treats as no dependencies" do
        class1 = test_class(name: "Class1", dependencies: nil)

        result = described_class.sort([class1])

        expect(sorted_names(result)).to eq(["Class1"])
      end
    end
  end
end
