# frozen_string_literal: true

RSpec.describe Admin::Config::CustomizeController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "#themes" do
    fab!(:theme1) { Fabricate(:theme, name: "Theme 1", component: false) }
    fab!(:theme2) { Fabricate(:theme, name: "Theme 2", component: false) }
    fab!(:component) { Fabricate(:theme, name: "Component", component: true) }

    it "returns only non-component themes" do
      get "/admin/config/customize/themes.json"

      expect(response.status).to eq(200)

      themes = response.parsed_body["themes"]
      theme_ids = themes.map { |t| t["id"] }

      expect(theme_ids).to include(theme1.id)
      expect(theme_ids).to include(theme2.id)
      expect(theme_ids).not_to include(component.id)
    end

    it "includes color scheme in response" do
      color_scheme = Fabricate(:color_scheme)
      theme1.update!(color_scheme_id: color_scheme.id)

      get "/admin/config/customize/themes.json"

      expect(response.status).to eq(200)

      theme_response = response.parsed_body["themes"].find { |t| t["id"] == theme1.id }
      expect(theme_response["color_scheme"]["id"]).to eq(color_scheme.id)
    end

    it "includes screenshot_url in response" do
      upload = UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(-1)
      theme1.set_field(
        target: :common,
        name: "screenshot",
        upload_id: upload.id,
        type: :theme_screenshot_upload_var,
      )
      theme1.save!

      get "/admin/config/customize/themes.json"

      expect(response.status).to eq(200)

      theme_response = response.parsed_body["themes"].find { |t| t["id"] == theme1.id }
      expect(theme_response["screenshot_url"]).to eq(upload.url)
    end
  end

  describe "#components" do
    fab!(:parent_theme_1) { Fabricate(:theme) }
    fab!(:parent_theme_2) { Fabricate(:theme) }

    fab!(:used_component) do
      Fabricate(
        :theme,
        name: "AweSome comp",
        component: true,
        parent_themes: [parent_theme_1, parent_theme_2],
      )
    end
    fab!(:unused_component) { Fabricate(:theme, name: "some comp", component: true) }
    fab!(:remote_component) do
      Fabricate(
        :theme,
        component: true,
        remote_theme: RemoteTheme.create!(remote_url: "https://github.com/discourse/discourse-tc"),
      )
    end
    fab!(:remote_component_with_update) do
      Fabricate(
        :theme,
        component: true,
        remote_theme:
          RemoteTheme.create!(
            remote_url: "https://github.com/discourse/discourse",
            commits_behind: 1,
          ),
      )
    end
    context "when filtering by `used`" do
      it "returns components that have a parent theme" do
        get "/admin/config/customize/components.json", params: { status: "used" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["components"].map { |c| c["id"] }).to contain_exactly(
          used_component.id,
        )
      end
    end

    context "when filtering by `unused`" do
      it "returns components that have no parent theme" do
        get "/admin/config/customize/components.json", params: { status: "unused" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["components"].map { |c| c["id"] }).to contain_exactly(
          unused_component.id,
          remote_component.id,
          remote_component_with_update.id,
        )
      end
    end

    context "when filtering by `updates_available`" do
      it "returns components that are behind their remote" do
        get "/admin/config/customize/components.json", params: { status: "updates_available" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["components"].map { |c| c["id"] }).to contain_exactly(
          remote_component_with_update.id,
        )
      end
    end

    context "when filtering by `all`" do
      it "returns all components" do
        get "/admin/config/customize/components.json", params: { status: "all" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["components"].map { |c| c["id"] }).to contain_exactly(
          used_component.id,
          unused_component.id,
          remote_component.id,
          remote_component_with_update.id,
        )
      end
    end

    context "when there's no filter param" do
      it "is equivalent to filtering by `all`" do
        get "/admin/config/customize/components.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["components"].map { |c| c["id"] }).to contain_exactly(
          used_component.id,
          unused_component.id,
          remote_component.id,
          remote_component_with_update.id,
        )
      end
    end

    it "can filter components by a search term" do
      get "/admin/config/customize/components.json", params: { name: "SomE" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["components"].map { |c| c["id"] }).to contain_exactly(
        used_component.id,
        unused_component.id,
      )
    end

    it "paginates the components list" do
      stub_const(Admin::Config::CustomizeController, "PAGE_SIZE", 2) do
        components = []

        get "/admin/config/customize/components.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["components"].size).to eq(2)
        components.concat(response.parsed_body["components"])
        expect(response.parsed_body["has_more"]).to eq(true)

        get "/admin/config/customize/components.json", params: { page: 1 }
        expect(response.status).to eq(200)
        expect(response.parsed_body["components"].size).to eq(2)
        components.concat(response.parsed_body["components"])
        expect(response.parsed_body["has_more"]).to eq(false)

        get "/admin/config/customize/components.json", params: { page: 2 }
        expect(response.status).to eq(200)
        expect(response.parsed_body["components"].size).to eq(0)
        expect(response.parsed_body["has_more"]).to eq(false)

        expect(components.map { |c| c["id"] }).to contain_exactly(
          used_component.id,
          unused_component.id,
          remote_component.id,
          remote_component_with_update.id,
        )
      end
    end
  end
end
