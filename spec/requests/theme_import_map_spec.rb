# frozen_string_literal: true

RSpec.describe "Theme cross-bundle plugin imports" do
  let(:theme) { Fabricate(:theme) }

  before { Fabricate(:admin) } # so "/" renders the app instead of the install wizard

  def import_map
    map = response.body[%r{<script type="importmap"[^>]*>(.*?)</script>}m, 1]
    JSON.parse(map)["imports"]
  end

  it "supplies a fake module for a plugin a theme imports but that isn't enabled" do
    theme.set_field(target: :extra_js, name: "discourse/initializers/cross-bundle.js", value: <<~JS)
        import Thing from "discourse/plugins/some-absent-plugin/lib/thing";
        export default { name: "cross-bundle", initialize() { Thing(); } };
      JS
    theme.save!
    SiteSetting.default_theme_id = theme.id

    get "/"
    expect(response.status).to eq(200)

    cache = theme.reload.javascript_cache
    expect(response.body).to include(
      %(<link rel="modulepreload" href="#{cache.url}" data-theme-id="#{theme.id}"),
    )

    expect(import_map["discourse/plugins/some-absent-plugin"]).to start_with(
      "data:text/javascript,",
    )
  end
end
