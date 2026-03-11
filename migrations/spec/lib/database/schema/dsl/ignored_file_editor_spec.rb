# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::IgnoredFileEditor do
  describe "#add_table" do
    it "preserves an existing tables-group reason when appending a table" do
      Dir.mktmpdir do |tmpdir|
        ignored_path = File.join(tmpdir, "ignored.rb")
        File.write(ignored_path, <<~RUBY)
            Migrations::Database::Schema.ignored do
              tables :a, :b, reason: "legacy"
            end
          RUBY

        allow(Migrations::Database::Schema::Helpers).to receive(:format_ruby_file)

        described_class.new(tmpdir).add_table(:c)

        content = File.read(ignored_path)
        expect(content).to include('tables :a, :b, :c, reason: "legacy"')
      end
    end
  end
end
