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

  describe '#download' do
    context 'not logged in as admin' do
      it "doesn't allow performing #download" do
        get "/admin/logs/watched_words/action/block/download"
        expect(response.status).to eq(404)
      end
    end

    context 'logged in as admin' do
      before do
        sign_in(admin)
      end

      it "words of different actions are downloaded separately" do
        block_word_1 = Fabricate(:watched_word, action: WatchedWord.actions[:block])
        block_word_2 = Fabricate(:watched_word, action: WatchedWord.actions[:block])
        censor_word_1 = Fabricate(:watched_word, action: WatchedWord.actions[:censor])

        get "/admin/logs/watched_words/action/block/download"
        expect(response.status).to eq(200)
        block_words = response.body.split("\n")
        expect(block_words).to contain_exactly(block_word_1.word, block_word_2.word)

        get "/admin/logs/watched_words/action/censor/download"
        expect(response.status).to eq(200)
        censor_words = response.body.split("\n")
        expect(censor_words).to eq([censor_word_1.word])
      end
    end
  end

  context '#clear_all' do
    context 'non admins' do
      it "doesn't allow them to perform #clear_all" do
        word = Fabricate(:watched_word, action: WatchedWord.actions[:block])
        delete "/admin/logs/watched_words/action/block"
        expect(response.status).to eq(404)
        expect(WatchedWord.pluck(:word)).to include(word.word)
      end
    end

    context 'admins' do
      before do
        sign_in(admin)
      end

      it "allows them to perform #clear_all" do
        word = Fabricate(:watched_word, action: WatchedWord.actions[:block])
        delete "/admin/logs/watched_words/action/block.json"
        expect(response.status).to eq(200)
        expect(WatchedWord.pluck(:word)).not_to include(word.word)
      end

      it "doesn't delete words of multiple actions in one call" do
        block_word = Fabricate(:watched_word, action: WatchedWord.actions[:block])
        flag_word = Fabricate(:watched_word, action: WatchedWord.actions[:flag])

        delete "/admin/logs/watched_words/action/flag.json"
        expect(response.status).to eq(200)
        all_words = WatchedWord.pluck(:word)
        expect(all_words).to include(block_word.word)
        expect(all_words).not_to include(flag_word.word)
      end
    end
  end
end
