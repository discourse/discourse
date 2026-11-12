# frozen_string_literal: true

RSpec.describe "Discourse Workflows | node names" do
  fab!(:admin)

  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }

  before { sign_in(admin) }

  def build_two_node_workflow
    editor_page.visit_new
    editor_page.click_empty_state_add_node
    editor_page.select_node_type("trigger:topic_created")
    editor_page.click_add_node
    editor_page.select_node_type("action:post", operation: "create")
  end

  def import_nodes(nodes)
    file = Tempfile.new(%w[workflow .json])
    file.write({ nodes: nodes, connections: {} }.to_json)
    file.flush
    page.find("input[type='file'][accept='.json']", visible: :all).set(file.path)
    file
  end

  it "blocks renaming a node to a name another node already uses" do
    build_two_node_workflow

    editor_page.double_click_node(1)
    find(".workflows-configurator-modal__name").click
    find(".workflows-configurator-modal__name-input").fill_in(with: "Topic created")

    expect(page).to have_css(".workflows-configurator-modal__name-error")
    expect(find(".workflows-configurator-modal__save-name")).to be_disabled
    expect(page).to have_no_css(".dialog-body")
  end

  it "renames imported nodes that collide with existing ones" do
    build_two_node_workflow

    import_nodes(
      [{ type: "action:post", typeVersion: "1.0", name: "Topic created", parameters: {} }],
    )

    expect(editor_page).to have_node_count(3)
    expect(editor_page).to have_node("Topic created 1")
    expect(page).to have_no_css(".dialog-body")
  end

  it "names imported nodes that arrive without one" do
    build_two_node_workflow

    import_nodes([{ type: "action:http_request", typeVersion: "1.0", parameters: {} }])

    expect(editor_page).to have_node_count(3)
    expect(page).to have_no_css(".dialog-body")
  end
end
