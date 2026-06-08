# frozen_string_literal: true

RSpec.describe Migrations::Converters do
  let(:root_path) { Dir.mktmpdir }
  let(:converters_path) { File.join(root_path, "converters") }
  let(:private_path) { File.join(root_path, "private", "converters") }

  before do
    allow(described_class).to receive(:converters_path).and_return(converters_path)
    allow(described_class).to receive(:private_converters_path).and_return(private_path)
    reset_memoization(described_class, :@all_converters)
  end
  after do
    FileUtils.remove_dir(root_path, force: true)
    reset_memoization(described_class, :@all_converters)
  end

  def create_converters(public_names: [], private_names: [])
    public_names.each { |dir| FileUtils.mkdir_p(File.join(converters_path, dir)) }
    private_names.each { |dir| FileUtils.mkdir_p(File.join(private_path, dir)) }
  end

  describe ".all" do
    subject(:all) { described_class.all }

    it "excludes the framework infrastructure directories" do
      create_converters(public_names: described_class::NON_CONVERTER_DIRS + %w[foo bar])

      expect(all.keys).to contain_exactly("foo", "bar")
    end

    it "returns converters from the gem and the private directory" do
      create_converters(public_names: %w[foo bar], private_names: %w[baz qux])

      expect(all).to eq(
        {
          "foo" => File.join(converters_path, "foo"),
          "bar" => File.join(converters_path, "bar"),
          "baz" => File.join(private_path, "baz"),
          "qux" => File.join(private_path, "qux"),
        },
      )
    end

    it "raises an error if there a duplicate names" do
      create_converters(public_names: %w[foo bar], private_names: %w[foo baz qux])

      expect { all }.to raise_error(StandardError, /Duplicate converter name found: foo/)
    end
  end

  describe ".names" do
    subject(:names) { described_class.names }

    it "returns a sorted array of converter names" do
      create_converters(public_names: %w[adapter foo bar], private_names: %w[baz qux])

      expect(names).to eq(%w[bar baz foo qux])
    end
  end

  describe ".path_of" do
    it "returns the path of a converter" do
      create_converters(public_names: %w[adapter foo bar])

      expect(described_class.path_of("foo")).to eq(File.join(converters_path, "foo"))
    end

    it "raises an error if there is no converter" do
      create_converters(public_names: %w[adapter foo bar])

      expect { described_class.path_of("baz") }.to raise_error(
        StandardError,
        "Could not find a converter named 'baz'",
      )
      expect { described_class.path_of("adapter") }.to raise_error(
        StandardError,
        "Could not find a converter named 'adapter'",
      )
    end
  end

  describe ".default_settings_path" do
    it "returns the path of the default settings file" do
      create_converters(public_names: %w[foo bar])

      expect(described_class.default_settings_path("foo")).to eq(
        File.join(converters_path, "foo", "settings.yml"),
      )
      expect(described_class.default_settings_path("bar")).to eq(
        File.join(converters_path, "bar", "settings.yml"),
      )
    end

    it "raises an error if there is no converter" do
      create_converters(public_names: %w[foo bar])

      expect { described_class.default_settings_path("baz") }.to raise_error(
        StandardError,
        "Could not find a converter named 'baz'",
      )
    end
  end
end
