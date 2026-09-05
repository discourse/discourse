# frozen_string_literal: true

RSpec.describe ProblemCheck::InactiveIconSets do
  subject(:check) { described_class.new }

  after do
    SvgSprite.expire_cache
    Theme.clear_cache!
  end

  def declaring_component(marker)
    component = Fabricate(:theme, component: true, name: "#{marker} icons")
    component.set_field(
      target: :common,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      type: :json,
      value: { "map" => { "bell" => "#{marker}-bell" } }.to_json,
    )
    component.save!
    component
  end

  it "is fine with a single icon set" do
    Fabricate(:theme).add_relative_theme!(:child, declaring_component("first"))

    expect(check).to be_chill_about_it
  end

  it "is fine when two sets are installed on different themes" do
    Fabricate(:theme).add_relative_theme!(:child, declaring_component("first"))
    Fabricate(:theme).add_relative_theme!(:child, declaring_component("second"))

    expect(check).to be_chill_about_it
  end

  it "reports the component whose set is shadowed on the same theme" do
    theme = Fabricate(:theme)
    theme.add_relative_theme!(:child, declaring_component("first"))
    loser = declaring_component("second")
    theme.add_relative_theme!(:child, loser)

    expect(SvgSprite.inactive_icon_set_themes).to eq([[loser.name, loser.id]])
    expect(check).to have_a_problem.with_priority("low")
  end
end
