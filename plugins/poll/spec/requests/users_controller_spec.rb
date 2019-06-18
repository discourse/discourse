# frozen_string_literal: true

require "rails_helper"

describe Admin::UsersController do

  let(:admin) { Fabricate(:admin) }

  before { sign_in(admin) }

  describe '#destroy' do
    let(:delete_me) { Fabricate(:user) }

    context "user has voted" do
      let!(:topic) { Fabricate(:topic, user: admin) }
      let!(:post) { Fabricate(:post, topic: topic, user: admin, raw: "[poll]\n- a\n- b\n[/poll]") }

      it "deletes the user" do
        poll = Poll.last
        PollVote.create!(user: delete_me, poll: poll, poll_option: poll.poll_options.first)

        delete "/admin/users/#{delete_me.id}.json"
        expect(response.status).to eq(200)
        expect(User.exists?(id: delete_me.id)).to eq(false)
        expect(PollVote.exists?(user_id: delete_me.id)).to eq(false)
      end
    end
  end

end
