# frozen_string_literal: true

RSpec.describe ::Migrations::Converters do
  let(:root_path) { Dir.mktmpdir }
  let(:core_path) { File.join(root_path, "lib", "converters") }
  let(:private_path) { File.join(root_path, "private", "converters") }

  before do
    allow(::Migrations).to receive(:root_path).and_return(root_path)
    reset_memoization(described_class, :@all_converters)
  end
  after do
    FileUtils.remove_dir(root_path, force: true)
    reset_memoization(described_class, :@all_converters)
  end

  def create_converters(core_names: [], private_names: [])
    core_names.each { |dir| FileUtils.mkdir_p(File.join(core_path, dir)) }
    private_names.each { |dir| FileUtils.mkdir_p(File.join(private_path, dir)) }
  end

  describe ".all" do
    subject(:all) { described_class.all }

    it "returns all the converters except for 'base'" do
      create_converters(core_names: %w[base foo bar])

      expect(all).to eq(
        { "foo" => File.join(core_path, "foo"), "bar" => File.join(core_path, "bar") },
      )
    end

    it "returns converters from core and private directory" do
      create_converters(core_names: %w[base foo bar], private_names: %w[baz qux])

      expect(all).to eq(
        {
          "foo" => File.join(core_path, "foo"),
          "bar" => File.join(core_path, "bar"),
          "baz" => File.join(private_path, "baz"),
          "qux" => File.join(private_path, "qux"),
        },
      )
    end

    it "raises an error if there a duplicate names" do
      create_converters(core_names: %w[base foo bar], private_names: %w[foo baz qux])

      expect { all }.to raise_error(StandardError, /Duplicate converter name found: foo/)
    end
  end

  describe ".names" do
    subject(:names) { described_class.names }

    it "returns a sorted array of converter names" do
      create_converters(core_names: %w[base foo bar], private_names: %w[baz qux])

      expect(names).to eq(%w[bar baz foo qux])
    end
  end

  describe ".path_of" do
    it "returns the path of a converter" do
      create_converters(core_names: %w[base foo bar])

      expect(described_class.path_of("foo")).to eq(File.join(core_path, "foo"))
    end

    it "raises an error if there is no converter" do
      create_converters(core_names: %w[base foo bar])

      expect { described_class.path_of("baz") }.to raise_error(
        StandardError,
        "Could not find a converter named 'baz'",
      )
      expect { described_class.path_of("base") }.to raise_error(
        StandardError,
        "Could not find a converter named 'base'",
      )
    end
  end

  describe ".default_settings_path" do
    it "returns the path of the default settings file" do
      create_converters(core_names: %w[foo bar])

      expect(described_class.default_settings_path("foo")).to eq(
        File.join(core_path, "foo", "settings.yml"),
      )
      expect(described_class.default_settings_path("bar")).to eq(
        File.join(core_path, "bar", "settings.yml"),
      )
    end

    it "raises an error if there is no converter" do
      create_converters(core_names: %w[foo bar])

      expect { described_class.default_settings_path("baz") }.to raise_error(
        StandardError,
        "Could not find a converter named 'baz'",
      )
    end
  end
end
