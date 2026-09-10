# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::SettingValueResolver do
  describe "#resolve" do
    subject(:resolved) { described_class.new(schema).resolve }

    context "with a blank schema" do
      let(:schema) { nil }

      it { is_expected.to eq({}) }
    end

    context "with a field missing a key" do
      let(:schema) { [{ "type" => "string", "value" => "hi" }] }

      it "skips the entry" do
        expect(resolved).to eq({})
      end
    end

    context "with a string field" do
      let(:schema) { [{ "key" => "label", "type" => "string", "value" => "hello" }] }

      it { is_expected.to eq("label" => "hello") }
    end

    context "with a string field that has no value" do
      let(:schema) { [{ "key" => "label", "type" => "string", "value" => nil }] }

      it { is_expected.to eq("label" => nil) }
    end

    context "with an integer field" do
      let(:schema) { [{ "key" => "count", "type" => "integer", "value" => "42" }] }

      it { is_expected.to eq("count" => 42) }
    end

    context "with an integer field that has no value" do
      let(:schema) { [{ "key" => "count", "type" => "integer", "value" => nil }] }

      it { is_expected.to eq("count" => nil) }
    end

    context "with a category field" do
      let(:schema) { [{ "key" => "cat", "type" => "category", "value" => "7" }] }

      it { is_expected.to eq("cat" => 7) }
    end

    context "with a group field" do
      let(:schema) { [{ "key" => "grp", "type" => "group", "value" => "3" }] }

      it { is_expected.to eq("grp" => 3) }
    end

    context "with a boolean field set to true" do
      let(:schema) { [{ "key" => "enabled", "type" => "boolean", "value" => "true" }] }

      it { is_expected.to eq("enabled" => true) }
    end

    context "with a boolean field set to anything else" do
      let(:schema) { [{ "key" => "enabled", "type" => "boolean", "value" => "false" }] }

      it { is_expected.to eq("enabled" => false) }
    end

    context "with a boolean field that has no value" do
      let(:schema) { [{ "key" => "enabled", "type" => "boolean", "value" => nil }] }

      it { is_expected.to eq("enabled" => false) }
    end

    context "with a category_list field" do
      let(:schema) { [{ "key" => "cats", "type" => "category_list", "value" => "1|2|3" }] }

      it { is_expected.to eq("cats" => [1, 2, 3]) }
    end

    context "with a category_list field that has no value" do
      let(:schema) { [{ "key" => "cats", "type" => "category_list", "value" => nil }] }

      it { is_expected.to eq("cats" => []) }
    end

    context "with a group_list field" do
      let(:schema) { [{ "key" => "grps", "type" => "group_list", "value" => "4|5" }] }

      it { is_expected.to eq("grps" => [4, 5]) }
    end

    context "with a tag_list field" do
      let(:schema) { [{ "key" => "tags", "type" => "tag_list", "value" => "bug|feature" }] }

      it { is_expected.to eq("tags" => %w[bug feature]) }
    end

    context "with a simple_list field" do
      let(:schema) { [{ "key" => "list", "type" => "simple_list", "value" => "a|b|c" }] }

      it { is_expected.to eq("list" => %w[a b c]) }
    end

    context "with an enum field" do
      let(:schema) { [{ "key" => "priority", "type" => "enum", "value" => "high" }] }

      it { is_expected.to eq("priority" => "high") }
    end

    context "with multiple fields" do
      let(:schema) do
        [
          { "key" => "priority", "type" => "enum", "value" => "high" },
          { "key" => "notify_categories", "type" => "category_list", "value" => "2|24" },
        ]
      end

      it "resolves every field" do
        expect(resolved).to eq("priority" => "high", "notify_categories" => [2, 24])
      end
    end
  end
end
