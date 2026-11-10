# frozen_string_literal: true

RSpec.describe "user nav sidebar icons" do
  it "only names icons the sprite ships" do
    source = File.read(Rails.root.join("frontend/discourse/app/lib/sidebar/user-nav-sidebar.js"))
    icons = source.scan(/\bicon: "([^"]+)"/).flatten.uniq

    expect(icons).not_to be_empty
    expect(icons - SvgSprite.all_icons).to be_empty
  end
end
