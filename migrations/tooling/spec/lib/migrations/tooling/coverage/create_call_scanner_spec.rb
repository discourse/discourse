# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Coverage::CreateCallScanner do
  describe ".scan" do
    def scan(source)
      described_class.scan(source, path: "(spec)")
    end

    it "collects keyword names from a bare IntermediateDB receiver" do
      result = scan("IntermediateDB::User.create(username: 'a', trust_level: 1)")

      expect(result.columns["User"]).to contain_exactly(:username, :trust_level)
    end

    it "records the model with no columns when a call site passes none" do
      result = scan("IntermediateDB::User.create")

      expect(result.columns.keys).to contain_exactly("User")
      expect(result.columns["User"]).to be_empty
    end

    it "ignores positional arguments and only collects the keyword hash" do
      result = scan('IntermediateDB::User.create("positional", username: "a")')

      expect(result.columns["User"]).to contain_exactly(:username)
    end

    it "visits create calls nested inside other expressions" do
      result = scan("wrapper(IntermediateDB::User.create(username: 'a'))")

      expect(result.columns["User"]).to contain_exactly(:username)
    end

    it "treats an IntermediateDB constant that does not respond to create as unknown" do
      # `Enums` exists under IntermediateDB but is not a model.
      result = scan("IntermediateDB::Enums.create(foo: 1)")

      expect(result.columns).to be_empty
      expect(result.unknown_models).to eq("Enums" => ["(spec):1"])
    end

    it "resolves the constant without inheriting from enclosing scopes" do
      stub_const("TopLevelCreatable", Class.new { def self.create(**); end })

      result = scan("IntermediateDB::TopLevelCreatable.create(foo: 1)")

      expect(result.columns).to be_empty
      expect(result.unknown_models).to eq("TopLevelCreatable" => ["(spec):1"])
    end

    it "matches the trailing segment regardless of leading qualification" do
      bare = scan("IntermediateDB::User.create(username: 'a')")
      qualified = scan("Migrations::Database::IntermediateDB::User.create(name: 'n')")

      expect(bare.columns.keys).to contain_exactly("User")
      expect(qualified.columns.keys).to contain_exactly("User")
    end

    it "unions columns across all call sites of the same model" do
      source = <<~RUBY
        if condition
          IntermediateDB::User.create(username: "a", name: "n")
        else
          IntermediateDB::User.create(username: "a", trust_level: 1)
        end
      RUBY

      expect(scan(source).columns["User"]).to contain_exactly(:username, :name, :trust_level)
    end

    it "ignores .create calls on constants outside IntermediateDB" do
      result = scan("Other::User.create(foo: 1)\nSomeClass.create(bar: 2)")

      expect(result.columns).to be_empty
      expect(result.unknown_models).to be_empty
    end

    it "records IntermediateDB constants that do not resolve to a model as unknown" do
      result = scan("x = 1\nIntermediateDB::NotAModel.create(foo: 1)")

      expect(result.columns).to be_empty
      expect(result.unknown_models).to eq("NotAModel" => ["(spec):2"])
    end

    it "records every call site of an unknown model" do
      source = <<~RUBY
        IntermediateDB::NotAModel.create(foo: 1)
        IntermediateDB::NotAModel.create(bar: 2)
      RUBY

      expect(scan(source).unknown_models).to eq("NotAModel" => %w[(spec):1 (spec):2])
    end

    it "ignores methods other than create, such as Upload.create_for_url" do
      result = scan("IntermediateDB::Upload.create_for_url(url: 'x')")

      expect(result.columns).to be_empty
      expect(result.unknown_models).to be_empty
    end

    it "raises with the offending model in the message when a call site passes a ** splat" do
      expect { scan("IntermediateDB::User.create(**attributes)") }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
        /IntermediateDB::User\.create.*a `\*\*` splat/,
      )
    end

    it "raises with the offending model in the message on a non-literal keyword" do
      expect { scan("IntermediateDB::User.create(dynamic => 1)") }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
        /IntermediateDB::User\.create.*a non-literal keyword/,
      )
    end

    it "raises when a call site passes an interpolated symbol keyword" do
      expect { scan('IntermediateDB::User.create("col_#{x}": 1)') }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
        /non-literal keyword/,
      )
    end

    it "raises with the source path and every parse error detail" do
      expect { described_class.scan("x = 1\n1 +", path: "steps/users.rb") }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
        "Failed to parse steps/users.rb: unexpected end-of-input; expected an expression " \
          "after the operator (line 2), unexpected end-of-input, assuming it is closing " \
          "the parent top level context (line 2)",
      )
    end
  end
end
