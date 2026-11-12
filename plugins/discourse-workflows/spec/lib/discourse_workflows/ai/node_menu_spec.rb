# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::NodeMenu do
  let(:all_palette_nodes) do
    DiscourseWorkflows::Registry.nodes(include_disabled_plugins: true).select(&:palette_visible?)
  end

  it "lists each node type once with its description" do
    menu = described_class.text

    expect(menu).to include("- action:code: Run custom JavaScript code")
    expect(menu.lines.grep(/\A- action:code:/).size).to eq(1)
  end

  it "marks descriptions it truncates" do
    node_class = DiscourseWorkflows::Nodes::Code::V1
    allow(I18n).to receive(:t).and_call_original
    allow(I18n).to receive(:t).with(
      "js.discourse_workflows.node_descriptions.action:code",
      locale: :en,
      default: "",
    ).and_return("x" * 200)

    expect(described_class.line(node_class)).to eq(
      "- action:code: #{"x" * described_class::MAX_DESCRIPTION_LENGTH}… [truncated, 200 chars total]",
    )
  end

  it "stays small enough to preload into every authoring prompt" do
    length = described_class.text(all_palette_nodes).length

    expect(length).to be <= described_class::MAX_LENGTH,
    "The node menu is #{length} chars (limit #{described_class::MAX_LENGTH}). It is too large to " \
      "preload; switch node discovery to a search/lookup tool instead of raising the limit."
  end
end
