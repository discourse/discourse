# frozen_string_literal: true

RSpec.describe Jobs::RemoveUnusedUncategorizedCategory do
  let!(:uncategorized) { Category.find(SiteSetting.uncategorized_category_id) }

  before do
    UpcomingChangeEvent.create!(
      event_type: :automatically_promoted,
      upcoming_change_name:
        SiteSetting::Action::RemoveAndReplaceUncategorizedToggled::UPCOMING_CHANGE,
      event_data: {
        allow_uncategorized_topics: false,
        uncategorized_category_id: uncategorized.id,
      },
    )
    SiteSetting.uncategorized_category_id = -1
  end

  it "removes the category demoted on a site that was not allowing uncategorized topics" do
    described_class.new.execute_onceoff({})

    expect(Category.exists?(uncategorized.id)).to eq(false)
  end

  it "does nothing when the change is opted out of" do
    SiteSetting.remove_and_replace_uncategorized = false

    described_class.new.execute_onceoff({})

    expect(Category.exists?(uncategorized.id)).to eq(true)
  end
end
