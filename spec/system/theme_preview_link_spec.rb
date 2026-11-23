# frozen_string_literal: true

describe "Theme preview links" do
  fab!(:admin)
  fab!(:theme)

  before { sign_in(admin) }

  it "previews the theme when the link is followed inside the app" do
    visit("/latest")
    expect(page).to have_css("#main-outlet")
    expect(page).to have_no_css(
      "meta[name='discourse_theme_id'][content='#{theme.id}']",
      visible: false,
    )

    # a preview link in a post or chat message, which the app would otherwise
    # follow without loading the page again
    page.execute_script(<<~JS)
      const link = document.createElement("a");
      link.href = "/?preview_theme_id=#{theme.id}";
      link.className = "test-preview-link";
      link.textContent = "Preview";
      document.querySelector("#main-outlet").prepend(link);
    JS
    find(".test-preview-link").click

    expect(page).to have_css(
      "meta[name='discourse_theme_id'][content='#{theme.id}']",
      visible: false,
    )
    expect(page).to have_css("#global-notice-theme-preview")
    expect(page).to have_no_css("#global-notice-theme-preview-failed")
  end

  it "links from the preview notice back to the site without the preview" do
    color_scheme = Fabricate(:color_scheme)
    visit(
      "/latest?order=activity&preview_theme_id=#{theme.id}&preview_color_scheme_id=#{color_scheme.id}&preview_base_font=lora",
    )
    expect(page).to have_css(
      "meta[name='discourse_theme_id'][content='#{theme.id}']",
      visible: false,
    )

    find("#global-notice-theme-preview .exit-theme-preview").click

    expect(page).to have_current_path("/latest?order=activity")
    expect(page).to have_no_css("#global-notice-theme-preview")
    expect(page).to have_no_css(
      "meta[name='discourse_theme_id'][content='#{theme.id}']",
      visible: false,
    )
  end

  context "with a component that only holds styles" do
    fab!(:component) do
      Fabricate(:theme, component: true, enabled: false).tap do |component|
        component.set_field(
          target: :common,
          name: :scss,
          value: "body { background-color: rgb(255, 224, 240); }",
        )
        component.save!
      end
    end

    def body_background
      page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    end

    it "previews it on the current theme, even while it's disabled, until the preview ends" do
      visit("/latest?preview_component_ids=#{component.id}")

      expect(page).to have_css("#global-notice-theme-preview")
      expect(page).to have_no_css("#global-notice-theme-preview-failed")
      expect(body_background).to eq("rgb(255, 224, 240)")

      find("#global-notice-theme-preview .exit-theme-preview").click

      expect(page).to have_current_path("/latest")
      expect(page).to have_no_css("#global-notice-theme-preview")
      expect(body_background).not_to eq("rgb(255, 224, 240)")
    end

    it "says the preview failed for a component it can't preview" do
      component.set_field(
        target: :extra_js,
        name: "discourse/api-initializers/x.js",
        value: "export default {};",
      )
      component.save!

      visit("/latest?preview_component_ids=#{component.id}")

      expect(page).to have_css("#global-notice-theme-preview-failed")
      expect(body_background).not_to eq("rgb(255, 224, 240)")
    end
  end
end
