# frozen_string_literal: true

describe "Appearance styles on Horizon" do
  fab!(:admin)
  fab!(:topic, :topic_with_op)

  let(:horizon) { Theme.horizon_theme }
  let(:change) do
    result =
      AppearanceChange::DraftComponent.call(
        params: {
          name: "Rounded",
          parent_theme_id: horizon.id,
          styles: {
            variables: {
              "--d-button-border-radius" => "20px",
            },
          },
        },
        guardian: admin.guardian,
      )
    expect(result).to run_successfully
    result[:appearance_change]
  end

  before do
    SystemThemesManager.sync_theme!("horizon")
    horizon.set_default!
    sign_in(admin)
  end

  def button_radius
    page.evaluate_script(
      "getComputedStyle(document.documentElement).getPropertyValue('--d-button-border-radius').trim()",
    )
  end

  it "previews the styles on Horizon's own layout, then applies them once the component is enabled" do
    visit("/latest?preview_component_ids=#{change.theme_id}")

    expect(page).to have_css(".topic-list-item[data-topic-id='#{topic.id}'] td.hc-topic-card")
    expect(page).to have_css("#global-notice-theme-preview")
    expect(button_radius).to eq("20px")

    visit("/admin?preview_component_ids=#{change.theme_id}")
    expect(page).to have_css("body.admin-interface")
    expect(button_radius).not_to eq("20px")

    visit("/latest")
    expect(page).to have_css(".topic-list")
    expect(button_radius).not_to eq("20px")

    expect(
      AppearanceChange::Activate.call(
        params: {
          appearance_change_id: change.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully

    visit("/latest")
    expect(page).to have_css(".topic-list-item[data-topic-id='#{topic.id}'] td.hc-topic-card")
    expect(page).to have_no_css("#global-notice-theme-preview")
    expect(button_radius).to eq("20px")
  end
end
