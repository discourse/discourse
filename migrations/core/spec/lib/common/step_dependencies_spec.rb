# frozen_string_literal: true

RSpec.describe Migrations::StepDependencies do
  before do
    Object.const_set(
      "DependenciesTestModule",
      Module.new { const_set("BaseStep", Class.new { extend Migrations::StepDependencies }) },
    )

    DependenciesTestModule.const_set("Posts", Class.new(DependenciesTestModule::BaseStep))
    DependenciesTestModule.const_set("TopicUsers", Class.new(DependenciesTestModule::BaseStep))
    DependenciesTestModule.const_set("Users", Class.new(DependenciesTestModule::BaseStep))
    DependenciesTestModule.const_set("NotAStep", Class.new)
  end

  after { Object.send(:remove_const, "DependenciesTestModule") }

  describe ".depends_on" do
    it "resolves symbol names to sibling step classes" do
      DependenciesTestModule::Posts.depends_on(:topic_users, :users)

      expect(DependenciesTestModule::Posts.dependencies).to eq(
        [DependenciesTestModule::TopicUsers, DependenciesTestModule::Users],
      )
    end

    it "resolves string names to sibling step classes" do
      DependenciesTestModule::Posts.depends_on("topic_users")

      expect(DependenciesTestModule::Posts.dependencies).to eq([DependenciesTestModule::TopicUsers])
    end

    it "accumulates dependencies across multiple calls" do
      DependenciesTestModule::Posts.depends_on(:users)
      DependenciesTestModule::Posts.depends_on(:topic_users)

      expect(DependenciesTestModule::Posts.dependencies).to eq(
        [DependenciesTestModule::Users, DependenciesTestModule::TopicUsers],
      )
    end

    it "raises a NameError naming the declaring class and scope for unknown steps" do
      expect { DependenciesTestModule::Posts.depends_on(:missing_step) }.to raise_error(
        NameError,
        "Step 'MissingStep' (declared via depends_on in DependenciesTestModule::Posts) " \
          "not found in DependenciesTestModule",
      )
    end

    it "raises a NameError when the name resolves to a class that isn't a step" do
      expect { DependenciesTestModule::Posts.depends_on(:not_a_step) }.to raise_error(
        NameError,
        "Step 'NotAStep' (declared via depends_on in DependenciesTestModule::Posts) " \
          "not found in DependenciesTestModule",
      )
    end

    context "with a top-level constant matching the step name" do
      before { Object.const_set("GlobalStep", Class.new(DependenciesTestModule::BaseStep)) }
      after { Object.send(:remove_const, "GlobalStep") }

      it "doesn't resolve it" do
        # Constant lookup on a module falls back to top-level constants by
        # default; resolution has to stay within the steps namespace.
        expect { DependenciesTestModule::Posts.depends_on(:global_step) }.to raise_error(
          NameError,
          "Step 'GlobalStep' (declared via depends_on in DependenciesTestModule::Posts) " \
            "not found in DependenciesTestModule",
        )
      end
    end
  end

  describe ".dependencies" do
    it "defaults to an empty array" do
      expect(DependenciesTestModule::Posts.dependencies).to eq([])
    end

    it "doesn't bleed between sibling step classes" do
      DependenciesTestModule::Posts.depends_on(:users)

      expect(DependenciesTestModule::TopicUsers.dependencies).to eq([])
      expect(DependenciesTestModule::BaseStep.dependencies).to eq([])
    end
  end

  describe ".priority" do
    it "defaults to nil and acts as getter/setter" do
      expect(DependenciesTestModule::Posts.priority).to be_nil

      DependenciesTestModule::Posts.priority 5
      expect(DependenciesTestModule::Posts.priority).to eq(5)
    end

    it "doesn't bleed between sibling step classes" do
      DependenciesTestModule::Posts.priority 5

      expect(DependenciesTestModule::Users.priority).to be_nil
    end
  end

  context "with a subclass of a step class" do
    before do
      DependenciesTestModule.const_set("ExtendedUsers", Class.new(DependenciesTestModule::Users))
    end

    it "inherits the macros and keeps its own metadata" do
      DependenciesTestModule::Users.depends_on(:posts)
      DependenciesTestModule::ExtendedUsers.depends_on(:topic_users)
      DependenciesTestModule::ExtendedUsers.priority 1

      expect(DependenciesTestModule::ExtendedUsers.dependencies).to eq(
        [DependenciesTestModule::TopicUsers],
      )
      expect(DependenciesTestModule::ExtendedUsers.priority).to eq(1)
      expect(DependenciesTestModule::Users.dependencies).to eq([DependenciesTestModule::Posts])
      expect(DependenciesTestModule::Users.priority).to be_nil
    end
  end

  describe "name resolution scope" do
    context "with importer-shaped nesting (steps inside a Steps module)" do
      before do
        DependenciesTestModule.const_set("Steps", Module.new)
        DependenciesTestModule::Steps.const_set(
          "Alpha",
          Class.new(DependenciesTestModule::BaseStep),
        )
        DependenciesTestModule::Steps.const_set("Beta", Class.new(DependenciesTestModule::BaseStep))
      end

      it "resolves names in the declaring step's own namespace" do
        DependenciesTestModule::Steps::Beta.depends_on(:alpha)

        expect(DependenciesTestModule::Steps::Beta.dependencies).to eq(
          [DependenciesTestModule::Steps::Alpha],
        )
      end

      it "doesn't resolve names from other namespaces" do
        expect { DependenciesTestModule::Steps::Beta.depends_on(:users) }.to raise_error(NameError)
      end
    end

    context "with converter-shaped nesting (steps as direct siblings)" do
      it "resolves names in the declaring step's own namespace" do
        DependenciesTestModule::Posts.depends_on(:users)

        expect(DependenciesTestModule::Posts.dependencies).to eq([DependenciesTestModule::Users])
      end
    end
  end

  describe "the dependency base class captured by `extend`" do
    it "captures each extending hierarchy independently" do
      DependenciesTestModule.const_set(
        "OtherBase",
        Class.new { extend Migrations::StepDependencies },
      )
      DependenciesTestModule.const_set("OtherStep", Class.new(DependenciesTestModule::OtherBase))

      expect { DependenciesTestModule::OtherBase.depends_on(:other_step) }.not_to raise_error
      expect { DependenciesTestModule::OtherBase.depends_on(:posts) }.to raise_error(NameError)
    end
  end
end
