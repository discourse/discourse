# frozen_string_literal: true

RSpec.describe Jobs::CleanUpAppearanceChangeDrafts do
  it "removes drafts that haven't gone live within a week, with what they created" do
    abandoned_draft = Fabricate(:theme_appearance_change, created_at: 8.days.ago)
    recent_draft = Fabricate(:theme_appearance_change, created_at: 6.days.ago)
    activated =
      Fabricate(:theme_appearance_change, created_at: 8.days.ago, activated_at: 8.days.ago)

    described_class.new.execute({})

    expect(AppearanceChange.all).to contain_exactly(recent_draft, activated)
    expect(Theme.exists?(abandoned_draft.theme_id)).to eq(false)
    expect(ColorScheme.exists?(abandoned_draft.light_color_scheme_id)).to eq(false)
  end
end
