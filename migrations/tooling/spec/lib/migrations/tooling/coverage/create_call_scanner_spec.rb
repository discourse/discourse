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

    it "ignores methods other than create, such as UploadSource.create_for_url" do
      result = scan("IntermediateDB::UploadSource.create_for_url(url: 'x')")

      expect(result.columns).to be_empty
      expect(result.unknown_models).to be_empty
    end

    it "raises when a call site passes a ** splat" do
      expect { scan("IntermediateDB::User.create(**attributes)") }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
        /splat/,
      )
    end

    it "raises when a call site passes a non-literal keyword" do
      expect { scan("IntermediateDB::User.create(dynamic => 1)") }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
        /non-literal keyword/,
      )
    end

    it "raises when a call site passes an interpolated symbol keyword" do
      expect { scan('IntermediateDB::User.create("col_#{x}": 1)') }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
        /non-literal keyword/,
      )
    end

    it "raises with the source path when the source cannot be parsed" do
      expect { described_class.scan("def broken(", path: "steps/users.rb") }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
        %r{steps/users\.rb},
      )
    end
  end
end
