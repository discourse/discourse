# frozen_string_literal: true

RSpec.describe Jobs::CleanUpAppearanceChangeDrafts do
  def fabricate_draft(age, **attributes)
    freeze_time(age.ago) { Fabricate(:theme_appearance_change, **attributes) }
  ensure
    unfreeze_time
  end

  it "removes drafts that haven't gone live within a week, with what they created" do
    abandoned_draft = fabricate_draft(8.days)
    recent_draft = fabricate_draft(6.days)
    activated = fabricate_draft(8.days, activated_at: 8.days.ago)

    described_class.new.execute({})

    expect(AppearanceChange.all).to contain_exactly(recent_draft, activated)
    expect(Theme.exists?(abandoned_draft.theme_id)).to eq(false)
    expect(ColorScheme.exists?(abandoned_draft.light_color_scheme_id)).to eq(false)
  end

  it "keeps an abandoned draft's palette once someone has edited it" do
    draft = fabricate_draft(8.days)
    draft.light_color_scheme.update!(name: "Our brand")

    described_class.new.execute({})

    expect(AppearanceChange.exists?(draft.id)).to eq(false)
    expect(ColorScheme.exists?(draft.light_color_scheme_id)).to eq(true)
    expect(ColorScheme.exists?(draft.dark_color_scheme_id)).to eq(false)
    expect(Theme.exists?(draft.theme_id)).to eq(false)
  end

  it "keeps an abandoned draft's theme, and the palettes it uses, once someone has edited it" do
    draft = fabricate_draft(8.days)
    draft.theme.update!(name: "Our theme")

    described_class.new.execute({})

    expect(AppearanceChange.exists?(draft.id)).to eq(false)
    expect(Theme.exists?(draft.theme_id)).to eq(true)
    expect(
      ColorScheme.where(id: [draft.light_color_scheme_id, draft.dark_color_scheme_id]).count,
    ).to eq(2)
  end
end
