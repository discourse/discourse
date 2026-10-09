# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TemplateStore do
  let(:template_path) { File.join(DiscourseWorkflows::TEMPLATES_PATH, "cached-template.json") }
  let(:broken_template_path) do
    File.join(DiscourseWorkflows::TEMPLATES_PATH, "broken-template.json")
  end
  let(:template_paths) { [template_path] }
  let(:template_json) do
    {
      name: "Cached template",
      description: "A cached template",
      nodes: [{ type: "trigger:topic_created" }, { type: "action:topic" }],
    }.to_json
  end

  before do
    described_class.reset_cache!
    Dir
      .stubs(:glob)
      .with(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
      .returns(template_paths)
    File.stubs(:read).with(template_path).returns(template_json)
  end

  after { described_class.reset_cache! }

  it "returns template summaries" do
    expect(described_class.summaries).to contain_exactly(
      {
        id: "cached-template",
        name: "Cached template",
        description: "A cached template",
        node_types: %w[trigger:topic_created action:topic],
      },
    )
  end

  it "returns copies so callers cannot mutate the cache" do
    described_class.find("cached-template")["name"] = "Mutated"
    described_class.summaries.first[:node_types].first.upcase!

    expect(described_class.find("cached-template")["name"]).to eq("Cached template")
    expect(described_class.summaries.first[:node_types].first).to eq("trigger:topic_created")
  end

  it "reads each template file once until the cache is reset" do
    File.expects(:read).with(template_path).twice.returns(template_json)

    described_class.summaries
    described_class.find("cached-template")
    described_class.reset_cache!
    described_class.find("cached-template")
  end

  context "with a malformed template file" do
    let(:template_paths) { [template_path, broken_template_path] }

    before { File.stubs(:read).with(broken_template_path).returns("not valid json{{{") }

    it "skips it" do
      expect(described_class.summaries.map { |t| t[:id] }).to contain_exactly("cached-template")
    end
  end
end
