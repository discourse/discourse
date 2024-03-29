# frozen_string_literal: true

require_relative "../../lib/migrations"

RSpec.describe Migrations do
  describe ".root_path" do
    it "returns the root path" do
      expect(described_class.root_path).to eq(File.expand_path("../..", __dir__))
    end
  end

  describe ".load_gemfiles" do
    it "exits with error if the gemfile does not exist" do
      relative_path = "does_not_exist"

      expect { described_class.load_gemfiles(relative_path) }.to output(
        include("Could not find Gemfile").and include(relative_path)
      ).to_stderr.and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end

    def with_temporary_root_path
      Dir.mktmpdir do |temp_dir|
        described_class.stubs(:root_path).returns(temp_dir)
        yield temp_dir
      end
    end

    it "exits with an error if the required Ruby version isn't found" do
      with_temporary_root_path do |root_path|
        gemfile_path = File.join(root_path, "config/gemfiles/test/Gemfile")
        FileUtils.mkdir_p(File.dirname(gemfile_path))
        File.write(gemfile_path, <<~GEMFILE)
            source "http://localhost"
            ruby "~> 100.0.0"
          GEMFILE

        expect { described_class.load_gemfiles("test") }.to output(
          include("your Gemfile specified ~> 100.0.0"),
        ).to_stderr.and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end
  end
end
