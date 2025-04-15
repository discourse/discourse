# frozen_string_literal: true

RSpec.describe Admin::Config::CustomizeController do
  fab!(:admin)
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

  before { sign_in(admin) }

  describe "#components" do
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
