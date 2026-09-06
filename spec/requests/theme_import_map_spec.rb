# frozen_string_literal: true

RSpec.describe "Theme cross-bundle plugin imports" do
  fab!(:theme)

  before { Fabricate(:admin) } # so "/" renders the app instead of the install wizard

  def import_map
    map = response.body[%r{<script type="importmap"[^>]*>(.*?)</script>}m, 1]
    JSON.parse(map)["imports"]
  end

  it "stubs imports of an absent plugin: null for optional, throwing for required" do
    theme.set_field(target: :extra_js, name: "discourse/initializers/cross-bundle.js", value: <<~JS)
        import Optional from "discourse/plugins/absent-optional-plugin/lib/thing" with { discourseImport: "optional" };
        import Required from "discourse/plugins/absent-required-plugin/lib/thing" with { discourseImport: "required" };
        export default { name: "cross-bundle", initialize() { Optional(); Required(); } };
      JS
    theme.save!
    SiteSetting.default_theme_id = theme.id

    get "/"
    expect(response.status).to eq(200)

    # Optional import of a missing plugin resolves to a null-returning stub.
    expect(import_map["discourse/plugins/absent-optional-plugin?"]).to eq(
      Plugin::JsManager.optional_plugin_stub,
    )

    # Required import of a missing plugin resolves to a stub that throws on import.
    expect(import_map["discourse/plugins/absent-required-plugin"]).to eq(
      Plugin::JsManager.required_plugin_stub("absent-required-plugin"),
    )
  end
end
