require 'rails_helper'

describe Jobs::RebakeAllHtmlThemeFields do
  let(:theme) { Fabricate(:theme) }
  let(:theme_field) { ThemeField.create!(theme: theme, target_id: 0, name: "header", value: "<script>console.log(123)</script>") }

  it 'extracts inline javascripts' do
    theme_field.update_attributes(value_baked: 'need to be rebaked')

    described_class.new.execute_onceoff({})

    theme_field.reload
    expect(theme_field.value_baked).to include('theme-javascripts')
  end
end
