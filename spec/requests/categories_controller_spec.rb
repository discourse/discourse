require 'rails_helper'

describe GroupsController do
  let(:admin) { Fabricate(:admin) }
  let(:category) { Fabricate(:category, user: admin) }

  before do
    category
    sign_in(admin)
  end

  it "triggers a extensibility event" do
    event = DiscourseEvent.track_events {
      put "/categories/#{category.id}.json", params: {
        name: 'hello',
        color: 'ff0',
        text_color: 'fff'
      }
    }.last

    expect(event[:event_name]).to eq(:category_updated)
    expect(event[:params].first).to eq(category)
  end
end
