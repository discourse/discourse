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
          animals_&_nature
          food_&_drink
          travel_&_places
          activities
          objects
          symbols
          flags
          default
        ],
      )
    end
  end

  describe "#search_aliases" do
    it "returns the search aliases list" do
      get "/emojis/search-aliases.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["grinning_face"]).to eq(
        %w[cheerful cheery face grin grinning happy laugh nice smile smiling teeth],
      )
    end
  end
end
