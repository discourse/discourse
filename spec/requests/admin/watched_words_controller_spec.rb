# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::WatchedWordsController do
  fab!(:admin) { Fabricate(:admin) }

  describe '#destroy' do
    fab!(:watched_word) { Fabricate(:watched_word) }

    before do
      sign_in(admin)
    end

    it 'should return the right response when given an invalid id param' do
      delete '/admin/logs/watched_words/9999.json'

      expect(response.status).to eq(400)
    end

    it 'should be able to delete a watched word' do
      delete "/admin/logs/watched_words/#{watched_word.id}.json"

      expect(response.status).to eq(200)
      expect(WatchedWord.find_by(id: watched_word.id)).to eq(nil)
    end
  end

  describe '#upload' do
    context 'logged in as admin' do
      before do
        sign_in(admin)
      end

      it 'creates the words from the file' do
        post '/admin/logs/watched_words/upload.json', params: {
          action_key: 'flag',
          file: Rack::Test::UploadedFile.new(file_from_fixtures("words.csv", "csv"))
        }

        expect(response.status).to eq(200)
        expect(WatchedWord.count).to eq(6)

        expect(WatchedWord.pluck(:word)).to contain_exactly(
          'thread', '线', 'धागा', '실', 'tråd', 'нить'
        )

        expect(WatchedWord.pluck(:action).uniq).to eq([WatchedWord.actions[:flag]])
      end
    end
  end
end
