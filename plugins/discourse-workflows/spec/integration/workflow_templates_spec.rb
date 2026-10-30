# frozen_string_literal: true

RSpec.describe "Workflow templates" do
  it "uses the latest version of every node and only its declared parameters" do
    Dir[File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json")].each do |path|
      JSON.parse(File.read(path))["nodes"].each do |node|
        label = "#{File.basename(path)} #{node["id"]} (#{node["type"]})"
        latest_version =
          DiscourseWorkflows::Registry.latest_version(node["type"], include_disabled_plugins: true)

        expect(node["typeVersion"]).to eq(latest_version), "#{label}: bump to #{latest_version}"

        node_type =
          DiscourseWorkflows::Registry.find_node_type(
            node["type"],
            version: latest_version,
            include_disabled_plugins: true,
          )
        undeclared = node["parameters"].keys - node_type.properties.keys.map(&:to_s)

        expect(undeclared).to be_empty, "#{label}: #{undeclared} not declared by #{latest_version}"
      end
    end
  end
end
