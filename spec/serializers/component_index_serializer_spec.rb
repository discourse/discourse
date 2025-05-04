# frozen_string_literal: true

RSpec.describe ComponentIndexSerializer do
  fab!(:theme_1) { Fabricate(:theme) }
  fab!(:theme_2) { Fabricate(:theme) }

  fab!(:component) do
    Fabricate(
      :theme,
      component: true,
      parent_themes: [theme_1, theme_2],
      remote_theme:
        RemoteTheme.create!(
          remote_url: "https://github.com/discourse/discourse.git",
          commits_behind: 3,
          authors: "CDCK Inc.",
        ),
      theme_fields: [
        ThemeField.new(
          name: "en",
          type_id: ThemeField.types[:yaml],
          target_id: Theme.targets[:translations],
          value: <<~YAML,
            en:
              theme_metadata:
                description: "Description of my component"
          YAML
        ),
      ],
    )
  end

  let(:json) { described_class.new(component, root: false).as_json }

  it "includes remote_theme object" do
    expect(json[:remote_theme][:id]).to eq(component.remote_theme.id)
    expect(json[:remote_theme][:commits_behind]).to eq(3)
    expect(json[:remote_theme][:authors]).to eq("CDCK Inc.")
  end

  it "includes parent themes objects" do
    expect(json[:parent_themes].map { |o| o[:name] }).to contain_exactly(theme_1.name, theme_2.name)
  end

  it "includes the component name" do
    expect(json[:name]).to eq(component.name)
  end

  it "includes the component id" do
    expect(json[:id]).to eq(component.id)
  end

  it "includes the component description" do
    expect(json[:description]).to eq("Description of my component")
  end
end
