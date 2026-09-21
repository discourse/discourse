# frozen_string_literal: true

RSpec.describe "Discourse Workflows - Node packs" do
  fab!(:admin)

  let(:manifest_path) do
    Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json")
  end
  let(:manifest) { File.read(manifest_path) }
  let(:node_packs_path) { "/admin/plugins/discourse-workflows/node-packs" }
  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }

  before { sign_in(admin) }

  def install_pack(value = manifest)
    DiscourseWorkflows::NodePack::Install.call(
      params: {
        manifest: value,
        approved_destinations: ["https://api.typesafe.ai"],
      },
      guardian: admin.guardian,
    )[
      :node_pack
    ]
  end

  it "previews, approves, installs, lists, and shows a pack through the real API" do
    page.visit(node_packs_path)
    click_button "Import pack"
    fill_in "Manifest JSON", with: manifest
    click_button "Preview"

    expect(page).to have_css(".workflows-node-pack-import__node", count: 4)
    expect(page).to have_content("Choose an option")
    expect(page).to have_content("https://api.typesafe.ai")

    find(".form-kit__control-checkbox-checkmark").click
    click_button "Install 4 nodes"

    pack = DiscourseWorkflows::NodePack.installed.find_by!(key: "jev")
    expect(page).to have_current_path("#{node_packs_path}/#{pack.id}")
    expect(page).to have_content("Jev")
    expect(page).to have_content("action:jev.choice")
    expect(page).to have_content("action:jev.batch")

    page.visit(node_packs_path)
    expect(page).to have_css(".workflows-node-packs__pack-link", text: "Jev")
  end

  it "uses the generic palette and configurator controls for all example nodes" do
    install_pack

    editor_page.visit_new
    editor_page.click_empty_state_add_node
    editor_page.select_node_type("Choose an option")
    editor_page.double_click_node(0)

    expect(page).to have_css(
      ".workflows-configurator-modal__pack-name",
      text: "Jev / Choose an option",
    )
    expect(page).to have_field("State")
    state_field = find_field("State")
    page.execute_script(<<~JS, state_field, "={{ $json.post.raw }}")
        const field = arguments[0];
        const value = arguments[1];
        const setter = Object.getOwnPropertyDescriptor(
          HTMLTextAreaElement.prototype,
          "value"
        ).set;
        setter.call(field, value);
        field.dispatchEvent(new Event("input", { bubbles: true }));
      JS
    expect(page).to have_content("Options")
    click_button "Add item"
    expect(page).to have_field("Key")
    fill_in "Key", with: "billing"
    fill_in "Description", with: "Payments and refunds"
    editor_page.close_node_configurator

    editor_page.click_add_node
    editor_page.select_node_type("Score against a rubric")
    editor_page.double_click_node(1)
    expect(page).to have_field("What to rate")
    expect(page).to have_content("Levels (lowest first)")
    click_button "Add item"
    expect(page).to have_field("Level description")
    editor_page.close_node_configurator

    editor_page.click_add_node
    editor_page.select_node_type("Check a statement")
    editor_page.double_click_node(2)
    expect(page).to have_field("Statement to check")
    expect(page).to have_field("What yes means")
    expect(page).to have_field("What no means")
    editor_page.close_node_configurator

    editor_page.click_add_node
    editor_page.select_node_type("Evaluate questions")
    editor_page.double_click_node(3)
    expect(page).to have_content("Questions")
    click_button "Add item"
    expect(page).to have_field("Answer id")
    expect(page).to have_field("Question")
    expect(page).to have_field("Criteria (JSON)")
    fill_in "Criteria (JSON)", with: '{"true":"asks for a refund"}'
  end

  it "fails closed when disabled and preserves inert history across remove and reinstall" do
    pack = install_pack
    node_class = DiscourseWorkflows::Registry.find_node_type("action:jev.choice", version: "1.0")
    definition_id = node_class.pack_definition_id

    page.visit("#{node_packs_path}/#{pack.id}")
    click_button "Disable"
    within(".dialog-container") { click_button "Disable" }

    expect(page).to have_css(".badge-notification", text: "Disabled")
    expect(node_class.available?).to eq(false)

    click_button "Enable"
    expect(page).to have_css(".badge-notification", text: "Enabled")

    updated_manifest = JSON.parse(manifest)
    updated_manifest["version"] = "1.1.0"
    updated = install_pack(updated_manifest)
    expect(updated.version).to eq("1.1.0")
    expect(
      DiscourseWorkflows::NodePackDefinition
        .find(definition_id)
        .definition
        .dig("_effective", "approved_origins"),
    ).to eq(["https://api.typesafe.ai"])

    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        nodes: [
          {
            "id" => "choice-1",
            "type" => "action:jev.choice",
            "typeVersion" => "1.0",
            "name" => "Demo choice",
            "parameters" => {
            },
          },
        ],
      )
    blocked =
      DiscourseWorkflows::NodePack::Remove.call(
        params: {
          node_pack_id: pack.id,
        },
        guardian: admin.guardian,
      )
    expect(blocked).to fail_a_policy(:not_in_use)

    workflow.update!(nodes: [])
    workflow.snapshot!(user: admin)
    removed =
      DiscourseWorkflows::NodePack::Remove.call(
        params: {
          node_pack_id: pack.id,
        },
        guardian: admin.guardian,
      )
    expect(removed).to run_successfully
    expect(
      DiscourseWorkflows::Registry.find_node_type("action:jev.choice", version: "1.0"),
    ).to be_nil
    expect(DiscourseWorkflows::NodePackDefinition.find(definition_id)).to be_retired_at

    reinstalled_manifest = updated_manifest.deep_dup
    reinstalled_manifest["version"] = "1.2.0"
    reinstalled = install_pack(reinstalled_manifest)
    expect(reinstalled).to be_present
    expect(DiscourseWorkflows::NodePackDefinition.find(definition_id)).not_to be_retired_at
  end
end
