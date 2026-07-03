# frozen_string_literal: true

require "tempfile"

RSpec.describe Migrations::Tooling::Coverage::SchemaColumns do
  describe ".call" do
    subject(:models) { described_class.call }

    let(:namespace) { Migrations::Database::IntermediateDB }

    # Defines a `.create` singleton method on `object` whose `source_location`
    # points at a file containing the generated marker, so `generated?` treats
    # it as produced by `disco schema generate`.
    def make_generated!(object)
      marker = Migrations::Tooling::Schema::DSL::GeneratedFiles::MARKER
      file = Tempfile.new(%w[fake_model .rb])
      file.write("# #{marker}\ndef create; end\n")
      file.close
      object.instance_eval(File.read(file.path), file.path, 1)
      @tempfiles ||= []
      @tempfiles << file
      object
    end

    # Registers `value` under `const_name` in the IntermediateDB namespace for
    # the duration of the example, then removes it again.
    def with_constant(const_name, value)
      namespace.const_set(const_name, value)
      yield
    ensure
      namespace.send(:remove_const, const_name)
      Array(@tempfiles).each { |f| f.unlink }
    end

    it "includes generated models keyed by their constant name" do
      expect(models).to include("User", "Badge", "UserCustomField")
    end

    it "returns the models in sorted key order" do
      expect(models.keys).to eq(models.keys.sort)
    end

    it "skips constants that are not modules, even when they look generated" do
      plain = make_generated!(Object.new)

      with_constant(:FakePlainConst, plain) do
        expect(described_class.call).not_to include("FakePlainConst")
      end
    end

    it "includes class constants that look generated (a Class is a Module)" do
      klass = make_generated!(Class.new)

      with_constant(:FakeClassConst, klass) do
        expect(described_class.call).to include("FakeClassConst")
      end
    end

    it "skips modules whose create method has no source location" do
      mod = Module.new
      mod.singleton_class.send(:alias_method, :create, :object_id)

      with_constant(:FakeNilPathConst, mod) do
        expect(described_class.call).not_to include("FakeNilPathConst")
      end
    end

    it "excludes manual (hand-written) models" do
      expect(models).not_to include("Upload", "LogEntry")
    end

    it "splits required and optional columns from the create signature" do
      user = models.fetch("User")

      expect(user.required).to include(:original_id, :username, :created_at, :trust_level)
      expect(user.optional).to include(:active, :name)
      expect(user.required).not_to include(:active)
    end

    it "exposes all columns and the table name for a model" do
      badge = models.fetch("Badge")

      expect(badge.columns).to include(:original_id, :name)
      expect(badge.table_name).to eq("badges")
    end
  end
end
