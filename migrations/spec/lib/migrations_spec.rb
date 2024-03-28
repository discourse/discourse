# frozen_string_literal: true

require_relative "../../lib/migrations"

RSpec.describe Migrations do
  describe ".root_path" do
    it "returns the root path" do
      expect(described_class.root_path).to eq(
        File.expand_path("../..", __dir__)
      )
    end
  end

  describe ".load_gemfile" do
    it "exits with error if the gemfile does not exist" do
      relative_path = "does_not_exist/Gemfile"

      expect { described_class.load_gemfile(relative_path) }.to output(
        include("Could not find Gemfile").and include(relative_path)
      ).to_stderr.and raise_error(SystemExit) { |error|
                        expect(error.status).to eq(1)
                      }
    end

    context "with temporary root_path" do
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

          expect { described_class.load_gemfile("test/Gemfile") }.to output(
            include("your Gemfile specified ~> 100.0.0")
          ).to_stderr.and raise_error(SystemExit) { |error|
                            expect(error.status).to eq(1)
                          }
        end
      end
    end

    # it "loads the gemfile" do
    #   relative_path = "convert/Gemfile"
    #   path = File.join(described_class.root_path, "config/gemfiles", relative_path)
    #   allow(File).to receive(:exist?).with(path).and_return(true)
    #
    #   bundler_ui = instance_double(Bundler::UI::Shell)
    #   allow(Bundler::UI::Shell).to receive(:new).and_return(bundler_ui)
    #   allow(bundler_ui).to receive(:level=).with("confirm")
    #
    #   gemfile = <<~GEMFILE
    #     source "https://rubygems.org"
    #     gem "thor"
    #   GEMFILE
    #
    #   allow(File).to receive(:read).with(path).and_return(gemfile)
    #
    #   expect do described_class.load_gemfile(relative_path) end.to output(
    #     "Could not fine Gemfile at #{path}\n",
    #   ).to_stderr
    # end
  end

  #   describe ".configure_zeitwerk" do
  #     it "configures Zeitwerk" do
  #       loader = instance_double(Zeitwerk::Loader)
  #       allow(Zeitwerk::Loader).to receive(:new).and_return(loader)
  #
  #       root_path = described_class.root_path
  #       directories = %w[lib/common lib/converters]
  #       directories.each do |dir|
  #         expanded_path = File.expand_path(dir, root_path)
  #         expect(loader).to receive(:push_dir).with(expanded_path, namespace: described_class)
  #       end
  #       expect(loader).to receive(:setup)
  #
  #       described_class.configure_zeitwerk(*directories)
  #     end
  #   end
end
