# frozen_string_literal: true

RSpec.describe Migrations::Converters do
  let(:root_path) { Dir.mktmpdir }

  before { allow(Migrations).to receive(:root_path).and_return(root_path) }
  after { FileUtils.remove_dir(root_path, force: true) }

  describe ".converter_paths" do
    it "returns the paths of converters and excludes 'base'" do
      core_path = File.join(root_path, "lib/converters")
      %w[base foo bar].each { |dir| FileUtils.mkdir_p(File.join(core_path, dir)) }

      expect(described_class.converter_paths).to contain_exactly(
        File.join(core_path, "foo"),
        File.join(core_path, "bar"),
      )
    end

    it "returns converters from core and private directory" do
      core_path = File.join(root_path, "lib", "converters")
      private_path = File.join(root_path, "private", "converters")

      %w[base foo bar].each { |dir| FileUtils.mkdir_p(File.join(core_path, dir)) }
      %w[baz qux].each { |dir| FileUtils.mkdir_p(File.join(private_path, dir)) }

      expect(described_class.converter_paths).to contain_exactly(
        File.join(core_path, "foo"),
        File.join(core_path, "bar"),
        File.join(private_path, "baz"),
        File.join(private_path, "qux"),
      )
    end
  end

  describe ".converter_names" do
    it "returns a sorted array of converter names" do
      core_path = File.join(root_path, "lib", "converters")
      private_path = File.join(root_path, "private", "converters")

      %w[base foo bar].each { |dir| FileUtils.mkdir_p(File.join(core_path, dir)) }
      %w[baz qux].each { |dir| FileUtils.mkdir_p(File.join(private_path, dir)) }

      expect(described_class.converter_names).to eq(%w[bar baz foo qux])
    end

    it "raises an error if there a duplicate names" do
      core_path = File.join(root_path, "lib", "converters")
      private_path = File.join(root_path, "private", "converters")

      %w[base foo bar].each { |dir| FileUtils.mkdir_p(File.join(core_path, dir)) }
      %w[foo baz qux].each { |dir| FileUtils.mkdir_p(File.join(private_path, dir)) }

      expect { described_class.converter_names }.to raise_error(StandardError, /foo/)
    end
  end
end
