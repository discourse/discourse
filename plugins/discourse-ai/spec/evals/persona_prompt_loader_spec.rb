# frozen_string_literal: true

require_relative "../../evals/lib/persona_prompt_loader"

RSpec.describe DiscourseAi::Evals::PersonaPromptLoader do
  subject(:loader) { described_class.new }

  let(:tmpdir) { Dir.mktmpdir }
  let(:yaml_path) { File.join(tmpdir, "custom.yml") }

  before do
    File.write(yaml_path, <<~YAML)
        key: custom_eval_persona
        description: Custom prompt for evals
        system_prompt: "Always summarize in one sentence."
      YAML

    allow(Dir).to receive(:glob).and_return([yaml_path])
  end

  after { FileUtils.remove_entry(tmpdir) }

  it "lists persona keys" do
    expect(loader.list).to eq([["custom_eval_persona", "Custom prompt for evals"]])
  end

  it "returns the system prompt for a key" do
    expect(loader.find_prompt("custom_eval_persona")).to eq("Always summarize in one sentence.")
  end

  it "returns nil when the key is missing" do
    expect(loader.find_prompt("missing")).to be_nil
  end
end
