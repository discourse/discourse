# frozen_string_literal: true

RSpec.describe "Remote theme update" do
  let :about_json do
    <<~JSON
      {
        "name": "awesome theme",
        "about_url": "https://www.site.com/about",
        "license_url": "https://www.site.com/license",
        "theme_version": "1.0",
        "minimum_discourse_version": "1.0.0",
        "assets": {
          "font": "assets/font.woff2"
        },
        "color_schemes": {
          "Amazing": {
            "love": "FAFAFA",
            "tertiary-low": "FFFFFF"
          }
        }
      }
    JSON
  end

  let :initial_repo do
    setup_git_repo("about.json" => about_json)
  end

  let :initial_repo_url do
    MockGitImporter.register("https://example.com/initial_repo.git", initial_repo)
  end

  after { `rm -fr #{initial_repo}` }

  around(:each) { |group| MockGitImporter.with_mock { group.run } }

  it "updates the base schemes for schemes that have diverged colors" do
    add_to_git_repo(
      initial_repo,
      "about.json" =>
        JSON
          .parse(about_json)
          .merge(
            color_schemes: {
              scheme1: {
                love: "FFFFFF",
                tertiary_low: "000000",
              },
              scheme2: {
                love: "AACCDD",
                tertiary_low: "99AAFF",
              },
            },
          )
          .to_json,
    )

    theme = RemoteTheme.import_theme(initial_repo_url)
    scheme1 = theme.color_schemes.find_by(name: "scheme1")
    scheme2 = theme.color_schemes.find_by(name: "scheme2")
    expect(scheme1.base_scheme_id).to eq(nil)
    expect(scheme2.base_scheme_id).to eq(nil)

    ColorSchemeRevisor.revise(scheme1, { colors: [{ name: "love", hex: "111111" }] })

    scheme1_base_scheme_id = scheme1.reload.base_scheme_id
    expect(scheme1_base_scheme_id).to be_present
    expect(scheme1.colors.find_by(name: "love").hex).to eq("111111")
    expect(
      ColorScheme.unscoped.find(scheme1_base_scheme_id).colors.find_by(name: "love").hex,
    ).to eq("ffffff")
    expect(scheme2.base_scheme_id).to eq(nil)

    add_to_git_repo(
      initial_repo,
      "about.json" =>
        JSON
          .parse(about_json)
          .merge(
            color_schemes: {
              scheme1: {
                love: "EEEEEE",
                tertiary_low: "000000",
              },
              scheme2: {
                love: "AACCDD",
                tertiary_low: "99AAFF",
              },
            },
          )
          .to_json,
    )
    theme.remote_theme.update_from_remote

    scheme1.reload
    expect(scheme1.base_scheme_id).to eq(scheme1_base_scheme_id)
    expect(scheme1.colors.find_by(name: "love").hex).to eq("111111")
    expect(
      ColorScheme.unscoped.find(scheme1_base_scheme_id).colors.find_by(name: "love").hex,
    ).to eq("eeeeee")
    expect(scheme2.base_scheme_id).to eq(nil)
  end

  it "deletes color schemes that haven't been modified and deletes the bases of schemes that have been modified" do
    add_to_git_repo(
      initial_repo,
      "about.json" =>
        JSON
          .parse(about_json)
          .merge(
            color_schemes: {
              scheme1: {
                love: "FFFFFF",
                tertiary_low: "000000",
              },
              scheme2: {
                love: "AACCDD",
                tertiary_low: "99AAFF",
              },
            },
          )
          .to_json,
    )

    theme = RemoteTheme.import_theme(initial_repo_url)

    scheme1 = theme.color_schemes.find_by(name: "scheme1")
    scheme2 = theme.color_schemes.find_by(name: "scheme2")

    expect do
      ColorSchemeRevisor.revise(scheme1, { colors: [{ name: "love", hex: "111111" }] })
    end.to change { ColorScheme.unscoped.count }.by(1)

    expect(scheme1.reload.base_scheme_id).to be_present
    expect(scheme2.reload.base_scheme_id).to be_blank

    scheme1_base_scheme_id = scheme1.base_scheme_id

    add_to_git_repo(
      initial_repo,
      "about.json" => JSON.parse(about_json).merge(color_schemes: {}).to_json,
    )

    expect do theme.remote_theme.update_from_remote end.to change { ColorScheme.unscoped.count }.by(
      -2,
    )

    expect(ColorScheme.unscoped.exists?(id: scheme1_base_scheme_id)).to eq(false)
    expect(ColorScheme.unscoped.exists?(id: scheme1.id)).to eq(true)
    expect(ColorScheme.unscoped.exists?(id: scheme2.id)).to eq(false)
  end
end
