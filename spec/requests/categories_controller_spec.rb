require 'rails_helper'

describe CategoriesController do

  context 'index' do

    it 'suppresses categories correctly' do
      post = create_post(title: 'super AMAZING AMAZING post')

      get "/categories"
      expect(response.body).to include('AMAZING AMAZING')

      post.topic.category.update_columns(suppress_from_latest: true)

      get "/categories"
      expect(response.body).not_to include('AMAZING AMAZING')
    end
  end

  context 'extensibility event' do
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
end
