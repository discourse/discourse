# frozen_string_literal: true

describe "Wireframe designs" do
  fab!(:admin)

  let(:editor) { PageObjects::Pages::WireframeEditor.new }

  before do
    SiteSetting.wireframe_enabled = true
    SiteSetting.has_login_hint = false
    Fabricate(
      :theme_site_setting_with_service,
      theme: Theme.find_default,
      name: "custom_homepage",
      value: true,
    )
    sign_in(admin)
  end

  def designs
    DiscourseWireframe::BlockLayoutCompanion.designs_for(Theme.find_default.id)
  end

  it "names the design from the header and keeps renaming the same design" do
    visit("/")
    find(".wireframe-empty-homepage__add").click
    expect(editor).to have_design_name("Untitled layout")

    editor.rename_design("Spring launch")
    editor.add_block_to_empty_outlet("divider")
    editor.publish
    expect(editor).to have_reader
    expect(designs.map { _1[:name] }).to eq(["Spring launch"])

    find(".wireframe-pill").click
    expect(editor).to have_design_name("Spring launch")
    editor.rename_design("Spring Launch")
    expect(editor).to have_design_name("Spring Launch")

    try_until_success { expect(designs.map { _1[:name] }).to eq(["Spring Launch"]) }
  end

  it "publishes to the installed design after a reload instead of creating another" do
    visit("/")
    find(".wireframe-empty-homepage__add").click
    editor.rename_design("Spring launch")
    editor.add_block_to_empty_outlet("divider")
    editor.publish
    expect(editor).to have_reader

    page.refresh
    find(".wireframe-pill").click
    expect(editor).to have_design_name("Spring launch")
    editor.rename_design("Spring Launch")
    find(".wireframe-block-chrome[data-wf-block-name='divider']").click
    find("body").send_keys(:delete)
    editor.publish
    expect(editor).to have_reader

    expect(designs.map { _1[:name] }).to eq(["Spring Launch"])
  end

  it "lists designs on the plugin's Designs tab and deletes one there" do
    parent = Theme.find_default
    %w[Spring Autumn].each do |name|
      DiscourseWireframe::EnsureBlockLayoutCompanion.call(
        params: {
          theme_id: parent.id,
          name: name,
        },
        guardian: admin.guardian,
      )
    end

    visit("/admin/config/customize/layouts")
    expect(page).to have_css(".wireframe-designs__row", count: 2)
    expect(page).to have_css(".wireframe-designs__row", text: "Autumn")
    expect(page).to have_css(".wireframe-designs__status.--active", count: 1)

    spring = Theme.find_by(name: "Spring")
    within(".wireframe-designs__row[data-design-id='#{spring.id}']") do
      find(".wireframe-designs__use").click
    end
    expect(page).to have_css(
      ".wireframe-designs__row[data-design-id='#{spring.id}'] .wireframe-designs__status.--active",
    )

    within(".wireframe-designs__row[data-design-id='#{spring.id}']") do
      find(".wireframe-designs__menu").click
    end
    find(".wireframe-designs__delete").click
    find(".dialog-footer .btn-danger").click

    expect(page).to have_css(".wireframe-designs__row", count: 1)
    expect(designs.map { _1[:name] }).to eq(["Autumn"])
  end

  it "previews an unpublished layout on the live homepage for an admin" do
    DiscourseWireframe::EnsureBlockLayoutCompanion.call(
      params: {
        theme_id: Theme.find_default.id,
        name: "Autumn",
        install: false,
        drafts: [
          {
            outlet_name: "homepage-blocks",
            layout_json: {
              schema_version: 1,
              layout: [
                { block: "layout", args: { mode: "stack" }, children: [{ block: "divider" }] },
              ],
            }.to_json,
          },
        ],
      },
      guardian: admin.guardian,
    )
    autumn = Theme.find_by(name: "Autumn")

    visit("/?wf_preview=#{autumn.id}")
    expect(page).to have_css(".wireframe-draft-preview", text: "Autumn")
    expect(page).to have_css(".d-block-divider, [data-block-name='divider']")

    find(".wireframe-pill").click
    expect(page).to have_css(".wireframe-shell")
    expect(page).to have_no_css(".wireframe-draft-preview")
    expect(page).to have_current_path("/")
    expect(editor).to have_design_name("Autumn")

    visit("/?wf_preview=#{autumn.id}")
    expect(page).to have_css(".wireframe-draft-preview")
    find(".wireframe-draft-preview__link.--exit").click
    expect(page).to have_no_css(".wireframe-draft-preview")
  end

  it "tells an admin about a saved layout that isn't published yet" do
    DiscourseWireframe::EnsureBlockLayoutCompanion.call(
      params: {
        theme_id: Theme.find_default.id,
        name: "Autumn",
        install: false,
      },
      guardian: admin.guardian,
    )

    visit("/")
    expect(page).to have_css(".wireframe-empty-homepage", text: "Autumn")
    expect(page).to have_css(".wireframe-empty-homepage__preview")
  end

  it "keeps the editor pill off admin pages" do
    visit("/admin/plugins/discourse-wireframe/settings")
    expect(page).to have_no_css(".wireframe-pill")

    visit("/")
    expect(page).to have_css(".wireframe-pill")
  end

  it "lists layouts as a tab with breadcrumbs on the themes and components page" do
    visit("/admin/config/customize/themes")
    click_link(I18n.t("js.wireframe.admin.designs.tab"))

    expect(page).to have_current_path("/admin/config/customize/layouts")
    expect(page).to have_css(
      ".d-breadcrumbs__item",
      text: I18n.t("js.wireframe.admin.designs.title"),
    )
  end

  it "opens the designs list from the editor's design menu" do
    visit("/")
    find(".wireframe-empty-homepage__add").click
    find(".wireframe-design-title__menu").click
    find(".wireframe-design-switcher__manage").click

    expect(page).to have_current_path("/admin/config/customize/layouts")
    expect(page).to have_css(".wireframe-designs")
    expect(page).to have_no_css(".wireframe-shell")
  end

  context "when editing a design the theme doesn't use" do
    let(:divider_layout) do
      {
        schema_version: 1,
        layout: [{ block: "layout", args: { mode: "stack" }, children: [{ block: "divider" }] }],
      }.to_json
    end

    before do
      DiscourseWireframe::EnsureBlockLayoutCompanion.call(
        params: {
          theme_id: Theme.find_default.id,
          name: "Autumn",
          drafts: [{ outlet_name: "homepage-blocks", layout_json: divider_layout }],
        },
        guardian: admin.guardian,
      )
      DiscourseWireframe::EnsureBlockLayoutCompanion.call(
        params: {
          theme_id: Theme.find_default.id,
          name: "Spring",
        },
        guardian: admin.guardian,
      )
    end

    def edit_autumn
      autumn = Theme.find_by(name: "Autumn")
      visit("/admin/config/customize/layouts")
      within(".wireframe-designs__row[data-design-id='#{autumn.id}']") do
        find(".wireframe-designs__menu").click
      end
      find(".wireframe-designs__edit").click

      expect(editor).to have_design_name("Autumn")
      expect(page).to have_css(".wireframe-block-chrome[data-wf-block-name='divider']")
      find(".wireframe-block-chrome[data-wf-block-name='divider']").click
      find("body").send_keys(:delete)
      editor.save
      expect(editor).to have_saved
    end

    def active_design
      designs.find { _1[:active] }&.fetch(:name)
    end

    it "saves it as unpublished and keeps the current layout live" do
      edit_autumn

      expect(page).to have_css(".wireframe-status-chip.--draft")
      try_until_success do
        autumn = Theme.find_by(name: "Autumn")
        field = autumn.theme_fields.find_by(name: "homepage-blocks")
        expect(JSON.parse(field.value)["layout"].to_s).not_to include("divider")
      end
      expect(active_design).to eq("Spring")
    end

    it "makes it the live layout when set to published" do
      edit_autumn
      editor.set_status(:published)

      try_until_success { expect(active_design).to eq("Autumn") }
    end
  end
end
