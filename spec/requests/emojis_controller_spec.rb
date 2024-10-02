# frozen_string_literal: true

RSpec.describe EmojisController do
  fab!(:user_1) { Fabricate(:user) }

  before { sign_in(user_1) }

  describe "#index" do
    before do
      CustomEmoji.destroy_all
      CustomEmoji.create!(name: "cat", upload: Fabricate(:upload))
      Emoji.clear_cache
    end

    after do
      CustomEmoji.destroy_all
      Emoji.clear_cache
    end

    it "returns the emojis list" do
      get "/emojis.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.keys).to eq(
        %w[
          smileys_&_emotion
          people_&_body
          objects
          travel_&_places
          animals_&_nature
          food_&_drink
          activities
          flags
          symbols
          default
        ],
      )
    end
  end
end
