# frozen_string_literal: true

RSpec.describe Migrations::Importer::CLI::CacheCommand do
  it "shows export and restore usage without requiring Rails" do
    expect { described_class.new([]).call }.to output(/export.*restore/m).to_stdout
    expect { described_class.new(%w[export --help]).call }.to output(
      /SQLite cache output path/,
    ).to_stdout
    expect { described_class.new(%w[restore --help]).call }.to output(
      /SQLite cache input path/,
    ).to_stdout
  end

  it "requires an explicit path for both operations" do
    %w[export restore].each do |operation|
      expect { described_class.new([operation]).call }.to raise_error(
        Migrations::CLI::Command::MissingPositionalError,
        /cache_path/,
      )
    end
  end
end
