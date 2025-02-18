# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::PluginConfigValidator do
  subject(:validator) { described_class.new(config, errors) }

  let(:errors) { [] }
  let(:config) { { plugins: %w[footnote chat poll] } }
  let(:installed_plugins) do
    [
      instance_double(::Plugin::Instance, name: "footnote"),
      instance_double(::Plugin::Instance, name: "chat"),
      instance_double(::Plugin::Instance, name: "poll"),
    ]
  end

  before { allow(Discourse).to receive(:plugins).and_return(installed_plugins) }

  describe "#validate" do
    it "adds an error if configured plugins are not installed" do
      config[:plugins] = %w[foo poll bar footnote chat]

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.plugins.not_installed", plugin_names: "bar, foo"),
      )
    end

    it "adds an error for unconfigured installed plugins" do
      config[:plugins] = %w[poll]

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.plugins.additional_installed", plugin_names: "chat, footnote"),
      )
    end

    it "adds both errors for mismatched plugins" do
      config[:plugins] = %w[chat foo poll]

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.plugins.not_installed", plugin_names: "foo"),
        I18n.t("schema.validator.plugins.additional_installed", plugin_names: "footnote"),
      )
    end

    it "does not add errors when plugins match" do
      validator.validate
      expect(errors).to be_empty
    end
  end
end
