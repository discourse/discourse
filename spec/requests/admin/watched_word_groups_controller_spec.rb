# frozen_string_literal: true

RSpec.describe Admin::WatchedWordGroupsController do
  fab!(:admin)
  fab!(:user)
  fab!(:watched_word_group)
  fab!(:watched_word_1) { Fabricate(:watched_word, watched_word_group_id: watched_word_group.id) }
  fab!(:watched_word_2) { Fabricate(:watched_word, watched_word_group_id: watched_word_group.id) }

  describe "#create" do
    let(:valid_word_list) { %w[Fr33 Deals] }
    let(:invalid_word_list) { valid_word_list + ["bad" * 120] }

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "does not create a watched word group" do
        expect do
          post "/admin/customize/watched_word_groups.json",
               params: {
                 action_key: "flag",
                 words: valid_word_list,
               }

          expect(response.status).to eq(404)
        end.not_to change { WatchedWordGroup.count }
      end
    end

    context "when logged in as a staff user" do
      before { sign_in(admin) }

      it "creates and groups watched words" do
        expect do
          post "/admin/customize/watched_word_groups.json",
               params: {
                 action_key: "flag",
                 words: valid_word_list,
               }

          expect(response.status).to eq(200)

          response_body = response.parsed_body
          group = WatchedWordGroup.find(response_body["id"])

          expect(response_body["words"].count).to eq(2)
          expect(group.watched_words.pluck(:word)).to contain_exactly(*valid_word_list)
          expect(response_body["words"]).to match(
            [
              hash_including(
                "word" => valid_word_list[0],
                "watched_word_group_id" => group.id,
                "case_sensitive" => false,
                "replacement" => nil,
                "action" => WatchedWord.actions[:flag],
              ),
              hash_including(
                "word" => valid_word_list[1],
                "watched_word_group_id" => group.id,
                "case_sensitive" => false,
                "replacement" => nil,
                "action" => WatchedWord.actions[:flag],
              ),
            ],
          )

          expect(
            UserHistory.where(action: UserHistory.actions[:create_watched_word_group]).count,
          ).to eq(1)
        end.to change { WatchedWordGroup.count }.by(1)
      end

      it "creates and groups case-sensitive watched words" do
        expect do
          post "/admin/customize/watched_word_groups.json",
               params: {
                 action_key: "flag",
                 words: valid_word_list,
                 case_sensitive: true,
               }

          response_body = response.parsed_body
          group = WatchedWordGroup.find(response_body["id"])

          expect(response.status).to eq(200)
          expect(response_body["words"].count).to eq(2)
          expect(group.watched_words.pluck(:case_sensitive)).to contain_exactly(true, true)
        end.to change { WatchedWordGroup.count }.by(1)
      end

      it "neither creates nor groups watched words with an invalid word" do
        expect do
          expect(WatchedWord.count).to eq(2)

          post "/admin/customize/watched_word_groups.json",
               params: {
                 action_key: "flag",
                 words: invalid_word_list,
               }

          expect(WatchedWord.count).to eq(2)
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to be_present
        end.not_to change { WatchedWordGroup.count }
      end
    end
  end

  describe "#update" do
    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "does not update watched word group membership" do
        expect do
          put "/admin/customize/watched_word_groups/#{watched_word_group.id}.json",
              params: {
                action_key: "flag",
                words: [watched_word_1.word, "Fr33"],
              }

          expect(response.status).to eq(404)
        end.not_to change { WatchedWordGroup.count }
      end
    end

    context "when logged in as a staff user" do
      before { sign_in(admin) }

      it "updates watched word group membership" do
        expect do
          expect(watched_word_group.watched_words.map(&:word)).to contain_exactly(
            watched_word_1.word,
            watched_word_2.word,
          )

          put "/admin/customize/watched_word_groups/#{watched_word_group.id}.json",
              params: {
                action_key: WatchedWord.actions[watched_word_group.action],
                words: [watched_word_1.word, "Fr33"],
              }

          expect(response.status).to eq(200)
          expect(
            WatchedWord.where(watched_word_group_id: watched_word_group.id).map(&:word),
          ).to contain_exactly(watched_word_1.word, "Fr33")
          expect(response.parsed_body["words"]).to match(
            [
              hash_including(
                "word" => watched_word_1.word,
                "watched_word_group_id" => watched_word_group.id,
                "case_sensitive" => false,
                "replacement" => nil,
                "action" => watched_word_group.action,
              ),
              hash_including(
                "word" => "Fr33",
                "watched_word_group_id" => watched_word_group.id,
                "case_sensitive" => false,
                "replacement" => nil,
                "action" => watched_word_group.action,
              ),
            ],
          )
          expect(
            UserHistory.where(action: UserHistory.actions[:update_watched_word_group]).count,
          ).to eq(1)
        end.not_to change { WatchedWordGroup.count }
      end

      it "does not update membership with an invalid word" do
        expect do
          expect(watched_word_group.watched_words.pluck(:word)).to contain_exactly(
            watched_word_1.word,
            watched_word_2.word,
          )

          put "/admin/customize/watched_word_groups/#{watched_word_group.id}.json",
              params: {
                action_key: WatchedWord.actions[watched_word_group.action],
                words: [watched_word_1.word, "Fr33" * 120],
              }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to be_present
          expect(
            WatchedWord.where(watched_word_group_id: watched_word_group.id).pluck(:word),
          ).to contain_exactly(watched_word_1.word, watched_word_2.word)
        end.not_to change { WatchedWordGroup.count }
      end
    end
  end

  describe "#destroy" do
    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "does not delete watched word group membership" do
        expect do
          delete "/admin/customize/watched_word_groups/#{watched_word_group.id}.json"

          expect(response.status).to eq(404)
          expect(
            WatchedWord.where(watched_word_group: watched_word_group.id).pluck(:word),
          ).to contain_exactly(watched_word_1.word, watched_word_2.word)
        end.not_to change { WatchedWordGroup.count }
      end
    end

    context "when logged in as a staff user" do
      before { sign_in(admin) }

      it "deletes group and members" do
        expect do
          delete "/admin/customize/watched_word_groups/#{watched_word_group.id}.json"

          expect(response.status).to eq(200)
          expect(
            UserHistory.where(action: UserHistory.actions[:delete_watched_word_group]).count,
          ).to eq(1)
        end.to change { WatchedWordGroup.count }.by(-1).and change { WatchedWord.count }.by(-2)
      end

      it "does nothing with an invalid id" do
        expect do
          delete "/admin/customize/watched_word_groups/-100.json"

          expect(response.status).to eq(404)
        end.not_to change { WatchedWordGroup.count }
      end
    end
  end
end
