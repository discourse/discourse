# frozen_string_literal: true

RSpec.describe AppearanceStyles::VariableInventory do
  describe "#build" do
    fab!(:color_scheme) do
      Fabricate(
        :color_scheme,
        color_scheme_colors: [Fabricate(:color_scheme_color, name: "hover", hex: "ff00ff")],
      )
    end
    fab!(:theme) { Fabricate(:theme, color_scheme:) }

    before do
      theme.set_field(
        target: :common,
        name: :color_definitions,
        value: ":root { --d-theme-only-color: red; }",
      )
      theme.save!
      theme.set_default!
    end

    it "reads core's design variables from its compiled CSS, ignoring the site's theme" do
      inventory = described_class.new.build
      variables = inventory["variables"].index_by { |variable| variable["name"] }

      expect(variables["--d-border-radius"]).to include(
        "type" => "length",
        "scope" => "root",
        "default" => "4px",
      )
      expect(variables["--d-button-primary-bg-color"]).to include("type" => "color")
      expect(variables.keys).to all(match(/\A--(d|token|hljs)-/))
      expect(inventory["palette_variables"]).to include("--primary", "--tertiary-low")

      expect(variables).not_to have_key("--d-theme-only-color")
      expect(variables["--d-hover"]["default"]).not_to eq("#ff00ff")
    end
  end

  describe ".current" do
    let(:cache_path) { File.join(Dir.mktmpdir, "variables.json") }

    before { described_class.stubs(:cache_path).returns(cache_path) }
    after { FileUtils.rm_rf(File.dirname(cache_path)) }

    it "builds the list once and reuses it until core's stylesheets change" do
      inventory = { "variables" => [], "palette_variables" => ["--primary"] }
      described_class.any_instance.expects(:build).once.returns(inventory)

      expect(described_class.current).to eq(inventory)
      expect(described_class.current).to eq(inventory)
      expect(JSON.parse(File.read(cache_path))).to eq(inventory)
    end
  end
end
