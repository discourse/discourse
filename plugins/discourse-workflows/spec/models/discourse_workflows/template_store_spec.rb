# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TemplateStore do
  before { described_class.reset_cache! }
  after { described_class.reset_cache! }

  let(:template_path) { File.join(DiscourseWorkflows::TEMPLATES_PATH, "cached-template.json") }
  let(:broken_template_path) do
    File.join(DiscourseWorkflows::TEMPLATES_PATH, "broken-template.json")
  end
  let(:template_json) do
    {
      name: "Cached template",
      description: "A cached template",
      nodes: [{ type: "trigger:topic_created" }, { type: "action:topic" }],
    }.to_json
  end

  it "returns template summaries" do
    Dir
      .stubs(:glob)
      .with(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
      .returns([template_path])
    File.stubs(:read).with(template_path).returns(template_json)

    expect(described_class.summaries).to contain_exactly(
      {
        id: "cached-template",
        name: "Cached template",
        description: "A cached template",
        node_types: %w[trigger:topic_created action:topic],
      },
    )
  end

  it "returns a duplicated template" do
    Dir
      .stubs(:glob)
      .with(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
      .returns([template_path])
    File.stubs(:read).with(template_path).returns(template_json)

    template = described_class.find("cached-template")
    template["name"] = "Mutated"

    expect(described_class.find("cached-template")["name"]).to eq("Cached template")
  end

  it "returns duplicated summaries" do
    Dir
      .stubs(:glob)
      .with(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
      .returns([template_path])
    File.stubs(:read).with(template_path).returns(template_json)

    summary = described_class.summaries.first
    summary[:name].upcase!
    summary[:node_types].first.upcase!

    expect(described_class.summaries.first).to include(
      name: "Cached template",
      node_types: %w[trigger:topic_created action:topic],
    )
  end

  it "reuses parsed templates until the cache is reset" do
    Dir
      .stubs(:glob)
      .with(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
      .returns([template_path])
    File.expects(:read).with(template_path).once.returns(template_json)

    described_class.summaries
    described_class.find("cached-template")
  end

  it "skips malformed template JSON" do
    Dir
      .stubs(:glob)
      .with(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
      .returns([template_path, broken_template_path])
    File.stubs(:read).with(template_path).returns(template_json)
    File.stubs(:read).with(broken_template_path).returns("not valid json{{{")

    ids = described_class.summaries.map { |template| template[:id] }

    expect(ids).to contain_exactly("cached-template")
  end

  it "reloads templates after reset" do
    Dir
      .stubs(:glob)
      .with(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
      .returns([template_path])
    File.expects(:read).with(template_path).twice.returns(template_json)

    described_class.find("cached-template")
    described_class.reset_cache!
    described_class.find("cached-template")
  end
end
