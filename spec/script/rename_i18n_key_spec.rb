# frozen_string_literal: true

require "fileutils"
require "yaml"
require "tmpdir"
require_relative "../../script/rename_i18n_key"

RSpec.describe YamlKeyRenamer do
  let(:fixtures_path) { File.join(Rails.root, "spec", "fixtures", "i18n_rename") }
  let(:tmp_dir) { Dir.mktmpdir("i18n_rename_test") }
  let(:en_file) { File.join(tmp_dir, "server.en.yml") }
  let(:fr_file) { File.join(tmp_dir, "server.fr.yml") }
  let(:de_file) { File.join(tmp_dir, "server.de.yml") }

  before { FileUtils.cp_r(Dir[File.join(fixtures_path, "*")], tmp_dir) }

  after { FileUtils.rm_rf(tmp_dir) }

  def load_yaml(file)
    YAML.safe_load(File.read(file), aliases: true)
  end

  def yaml_data(file)
    data = load_yaml(file)
    data[data.keys.first]
  end

  def run_renamer(file, old_key, new_key)
    described_class.new(file, old_key, new_key).run
  end

  describe "simple rename" do
    it "renames a leaf key in all locales" do
      run_renamer(en_file, "simple_key", "basic_key")

      expect(yaml_data(en_file)).to include("basic_key" => "simple value")
      expect(yaml_data(en_file)).not_to have_key("simple_key")

      expect(yaml_data(fr_file)).to include("basic_key" => "valeur simple")
      expect(yaml_data(fr_file)).not_to have_key("simple_key")

      expect(yaml_data(de_file)).to include("basic_key" => "einfacher Wert")
      expect(yaml_data(de_file)).not_to have_key("simple_key")
    end

    it "renames a nested leaf key" do
      run_renamer(en_file, "post_action_types.inappropriate.title", "name")

      en = yaml_data(en_file)
      expect(en.dig("post_action_types", "inappropriate", "name")).to eq("Inappropriate")
      expect(en.dig("post_action_types", "inappropriate")).not_to have_key("title")

      fr = yaml_data(fr_file)
      expect(fr.dig("post_action_types", "inappropriate", "name")).to eq("Inapproprié")
    end

    it "renames a quoted key" do
      run_renamer(en_file, "education.new-topic", "new-topic-welcome")

      en = yaml_data(en_file)
      expect(en["education"]).to have_key("new-topic-welcome")
      expect(en["education"]).not_to have_key("new-topic")
      expect(en.dig("education", "new-topic-welcome")).to include("Thanks for contributing!")
    end

    it "only changes the target line in the file" do
      original_lines = File.readlines(en_file)
      run_renamer(en_file, "simple_key", "basic_key")
      new_lines = File.readlines(en_file)

      changed = original_lines.zip(new_lines).count { |a, b| a != b }
      expect(changed).to eq(1)
    end

    it "skips locales where the key does not exist" do
      run_renamer(en_file, "education.new-reply", "new-reply-welcome")

      en = yaml_data(en_file)
      expect(en["education"]).to have_key("new-reply-welcome")

      # FR has new-topic but not new-reply; file should still parse
      fr = yaml_data(fr_file)
      expect(fr["education"]).not_to have_key("new-reply-welcome")

      # DE has no education key at all
      de = yaml_data(de_file)
      expect(de).not_to have_key("education")
    end
  end

  describe "move" do
    it "moves a leaf to an existing parent" do
      run_renamer(en_file, "post_action_types.inappropriate.title", "post_action_types.spam.name")

      en = yaml_data(en_file)
      expect(en.dig("post_action_types", "spam", "name")).to eq("Inappropriate")
      expect(en.dig("post_action_types", "inappropriate")).not_to have_key("title")
      expect(en.dig("post_action_types", "spam", "title")).to eq("Spam")
    end

    it "moves a leaf to a new parent path" do
      run_renamer(en_file, "post_action_types.inappropriate.title", "flags.inappropriate.name")

      en = yaml_data(en_file)
      expect(en.dig("flags", "inappropriate", "name")).to eq("Inappropriate")
      expect(en.dig("post_action_types", "inappropriate")).not_to have_key("title")
    end

    it "moves a subtree with children" do
      run_renamer(en_file, "post_action_types.spam.count", "post_action_types.off_topic.flag_count")

      en = yaml_data(en_file)
      expect(en.dig("post_action_types", "off_topic", "flag_count", "one")).to eq("%{count} flag")
      expect(en.dig("post_action_types", "off_topic", "flag_count", "other")).to eq(
        "%{count} flags",
      )
      expect(en.dig("post_action_types", "spam")).not_to have_key("count")

      fr = yaml_data(fr_file)
      expect(fr.dig("post_action_types", "off_topic", "flag_count", "one")).to eq(
        "%{count} signalement",
      )
    end

    it "moves a multi-line value preserving content" do
      run_renamer(en_file, "post_action_types.spam.long_description", "flags.spam.details")

      en = yaml_data(en_file)
      expect(en.dig("flags", "spam", "details")).to eq("This post is spam\nand should be removed\n")
      expect(en.dig("post_action_types", "spam")).not_to have_key("long_description")
    end

    it "moves across locales including new parent creation" do
      run_renamer(en_file, "post_action_types.spam.count", "flags.spam_count")

      fr = yaml_data(fr_file)
      expect(fr.dig("flags", "spam_count", "one")).to eq("%{count} signalement")

      # DE has no spam key, so should be skipped
      de = yaml_data(de_file)
      expect(de).not_to have_key("flags")
    end
  end

  describe "error handling" do
    it "aborts when old key is not found" do
      expect { run_renamer(en_file, "nonexistent.key", "foo") }.to raise_error(SystemExit)
    end

    it "aborts when new key already exists" do
      expect { run_renamer(en_file, "simple_key", "dates") }.to raise_error(SystemExit)
    end

    it "aborts when file does not exist" do
      expect { run_renamer("/tmp/nonexistent.en.yml", "foo", "bar") }.to raise_error(SystemExit)
    end

    it "restores original file on YAML validation failure" do
      original_content = File.read(en_file)

      renamer = described_class.new(en_file, "simple_key", "basic_key")
      allow(YAML).to receive(:safe_load).and_raise(Psych::SyntaxError.new("", 0, 0, 0, "", ""))

      expect { renamer.run }.to output(/YAML validation failed/).to_stdout
      expect(File.read(en_file)).to eq(original_content)
    end
  end

  describe "output" do
    it "reports modified and skipped files" do
      output = capture_stdout { run_renamer(en_file, "education.new-reply", "farewell") }

      expect(output).to include("education.new-reply")
      expect(output).to include("server.en.yml")
      expect(output).to include("key not found, skipping")
      expect(output).to include("Done!")
    end
  end
end
