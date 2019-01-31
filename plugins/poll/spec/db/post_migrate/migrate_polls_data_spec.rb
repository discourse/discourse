require 'rails_helper'
require_relative '../../../db/post_migrate/20180820080623_migrate_polls_data'

RSpec.describe MigratePollsData do
  let!(:user) { Fabricate(:user, id: 1) }
  let!(:user2) { Fabricate(:user, id: 2) }
  let!(:user3) { Fabricate(:user, id: 3) }
  let!(:user4) { Fabricate(:user, id: 4) }
  let!(:user5) { Fabricate(:user, id: 5) }
  let(:post) { Fabricate(:post, user: user) }

  describe 'for a number poll' do
    before do
      post.custom_fields = {
        "polls" => {
          "poll" => {
            "options" => [
              { "id" => "4d8a15e3cc35750f016ce15a43937620", "html" => "1", "votes" => 0 },
              { "id" => "aa2393b424f2f395abb63bf785760a3b", "html" => "4", "votes" => 0 },
              { "id" => "9ab1070dec27185440cdabb4948a5e9a", "html" => "7", "votes" => 1 },
              { "id" => "46c01f638a50d86e020f47469733b8be", "html" => "10", "votes" => 0 },
              { "id" => "b4f15431e07443c372d521e4ed131abe", "html" => "13", "votes" => 0 },
              { "id" => "4e885ead68ff4456f102843df9fbbd7f", "html" => "16", "votes" => 0 },
              { "id" => "eb8661f072794ea57baa7827cd8ffc88", "html" => "19", "votes" => 0 }
            ],
            "voters" => 1,
            "name" => "poll",
            "status" => "open",
            "type" => "number",
            "min" => "1",
            "max" => "20",
            "step" => "3"
          },
        },
        "polls-votes" => {
          "1" => {
            "poll" => [
              "9ab1070dec27185440cdabb4948a5e9a"
            ]
          }
        }
      }

      post.save_custom_fields
    end

    it "should migrate the data correctly" do
      expect do
        silence_stdout { MigratePollsData.new.up }
      end.to \
        change { Poll.count }.by(1) &
        change { PollOption.count }.by(7) &
        change { PollVote.count }.by(1)

      poll = Poll.find_by(name: "poll", post: post)

      expect(poll.close_at).to eq(nil)

      expect(poll.number?).to eq(true)
      expect(poll.open?).to eq(true)
      expect(poll.always?).to eq(true)
      expect(poll.secret?).to eq(true)

      expect(poll.min).to eq(1)
      expect(poll.max).to eq(20)
      expect(poll.step).to eq(3)

      expect(PollOption.all.pluck(:digest, :html)).to eq([
        ["4d8a15e3cc35750f016ce15a43937620", "1"],
        ["aa2393b424f2f395abb63bf785760a3b", "4"],
        ["9ab1070dec27185440cdabb4948a5e9a", "7"],
        ["46c01f638a50d86e020f47469733b8be", "10"],
        ["b4f15431e07443c372d521e4ed131abe", "13"],
        ["4e885ead68ff4456f102843df9fbbd7f", "16"],
        ["eb8661f072794ea57baa7827cd8ffc88", "19"]
      ])

      poll_vote = PollVote.first

      expect(poll_vote.poll).to eq(poll)
      expect(poll_vote.poll_option.html).to eq("7")
      expect(poll_vote.user).to eq(user)
    end
  end

  describe 'for a multiple poll' do
    before do
      post.custom_fields = {
        "polls-votes" => {
          "1" => {
            "testing" => [
              "b2c3e3668a886d09e97e38b8adde7d45",
              "b2c3e3668a886d09e97e38b8adde7d45",
              "28df49fa9e9c09d3a1eb8cfbcdcda7790"
            ]
          },
          "2" => {
            "testing" => [
              "b2c3e3668a886d09e97e38b8adde7d45",
              "d01af008ec373e948c0ab3ad61009f35",
            ]
          },
        },
        "polls" => {
          "poll" => {
            "options" => [
              {
                "id" => "b2c3e3668a886d09e97e38b8adde7d45",
                "html" => "Choice 1",
                "votes" => 2,
                "voter_ids" => [user.id, user2.id]
              },
              {
                "id" => "28df49fa9e9c09d3a1eb8cfbcdcda7790",
                "html" => "Choice 2",
                "votes" => 1,
                "voter_ids" => [user.id]
              },
              {
                "id" => "d01af008ec373e948c0ab3ad61009f35",
                "html" => "Choice 3",
                "votes" => 1,
                "voter_ids" => [user2.id]
              },
            ],
            "voters" => 4,
            "name" => "testing",
            "status" => "closed",
            "type" => "multiple",
            "public" => "true",
            "min" => 1,
            "max" => 2
          }
        }
      }

      post.save_custom_fields
    end

    it 'should migrate the data correctly' do
      expect do
        silence_stdout { MigratePollsData.new.up }
      end.to \
        change { Poll.count }.by(1) &
        change { PollOption.count }.by(3) &
        change { PollVote.count }.by(4)

      poll = Poll.last

      expect(poll.post_id).to eq(post.id)
      expect(poll.name).to eq("testing")
      expect(poll.close_at).to eq(nil)

      expect(poll.multiple?).to eq(true)
      expect(poll.closed?).to eq(true)
      expect(poll.always?).to eq(true)
      expect(poll.everyone?).to eq(true)

      expect(poll.min).to eq(1)
      expect(poll.max).to eq(2)
      expect(poll.step).to eq(nil)

      poll_options = PollOption.all

      poll_option_1 = poll_options[0]
      expect(poll_option_1.poll_id).to eq(poll.id)
      expect(poll_option_1.digest).to eq("b2c3e3668a886d09e97e38b8adde7d45")
      expect(poll_option_1.html).to eq("Choice 1")

      poll_option_2 = poll_options[1]
      expect(poll_option_2.poll_id).to eq(poll.id)
      expect(poll_option_2.digest).to eq("28df49fa9e9c09d3a1eb8cfbcdcda7790")
      expect(poll_option_2.html).to eq("Choice 2")

      poll_option_3 = poll_options[2]
      expect(poll_option_3.poll_id).to eq(poll.id)
      expect(poll_option_3.digest).to eq("d01af008ec373e948c0ab3ad61009f35")
      expect(poll_option_3.html).to eq("Choice 3")

      expect(PollVote.all.pluck(:poll_id).uniq).to eq([poll.id])

      {
        user => [poll_option_1, poll_option_2],
        user2 => [poll_option_1, poll_option_3]
      }.each do |user, options|
        options.each do |option|
          expect(PollVote.exists?(poll_option_id: option.id, user_id: user.id))
            .to eq(true)
        end
      end
    end
  end

  describe 'for a regular poll' do
    before do
      post.custom_fields = {
        "polls" => {
          "testing" => {
            "options" => [
              {
                "id" => "e94c09aae2aa071610212a5c5042111b",
                "html" => "Yes",
                "votes" => 0,
                "anonymous_votes" => 1,
                "voter_ids" => []
              },
              {
                "id" => "802c50392a68e426d4b26d81ddc5ab33",
                "html" => "No",
                "votes" => 0,
                "anonymous_votes" => 2,
                "voter_ids" => []
              }
            ],
            "voters" => 0,
            "anonymous_voters" => 3,
            "name" => "testing",
            "status" => "open",
            "type" => "regular"
          },
          "poll" => {
            "options" => [
              {
                "id" => "edeee5dae4802ab24185d41039efb545",
                "html" => "Yes",
                "votes" => 2,
                "voter_ids" => [1, 2]
              },
              {
                "id" => "38d8e35c8fc80590f836f22189064835",
                "html" =>
                "No",
                "votes" => 3,
                "voter_ids" => [3, 4, 5]
              }
            ],
            "voters" => 5,
            "name" => "poll",
            "status" => "open",
            "type" => "regular",
            "public" => "true",
            "close" => "2018-10-08T00:00:00.000Z"
          },
        },
        "polls-votes" => {
          "1" => { "poll" => ["edeee5dae4802ab24185d41039efb545"] },
          "2" => { "poll" => ["edeee5dae4802ab24185d41039efb545"] },
          "3" => { "poll" => ["38d8e35c8fc80590f836f22189064835"] },
          "4" => { "poll" => ["38d8e35c8fc80590f836f22189064835"] },
          "5" => { "poll" => ["38d8e35c8fc80590f836f22189064835"] }
        }
      }

      post.save_custom_fields
    end

    it 'should migrate the data correctly' do
      expect do
        silence_stdout { MigratePollsData.new.up }
      end.to \
        change { Poll.count }.by(2) &
        change { PollOption.count }.by(4) &
        change { PollVote.count }.by(5)

      poll = Poll.find_by(name: "poll")

      expect(poll.post_id).to eq(post.id)
      expect(poll.close_at).to eq("2018-10-08T00:00:00.000Z")

      expect(poll.regular?).to eq(true)
      expect(poll.open?).to eq(true)
      expect(poll.always?).to eq(true)
      expect(poll.everyone?).to eq(true)

      expect(poll.min).to eq(nil)
      expect(poll.max).to eq(nil)
      expect(poll.step).to eq(nil)

      poll_options = PollOption.where(poll_id: poll.id).to_a
      expect(poll_options.size).to eq(2)

      option_1 = poll_options.first
      expect(option_1.digest).to eq("edeee5dae4802ab24185d41039efb545")
      expect(option_1.html).to eq("Yes")

      option_2 = poll_options.last
      expect(option_2.digest).to eq("38d8e35c8fc80590f836f22189064835")
      expect(option_2.html).to eq("No")

      expect(PollVote.pluck(:poll_id).uniq).to eq([poll.id])

      [user, user2].each do |user|
        expect(PollVote.exists?(poll_option_id: option_1.id, user_id: user.id))
          .to eq(true)
      end

      [user3, user4, user5].each do |user|
        expect(PollVote.exists?(poll_option_id: option_2.id, user_id: user.id))
          .to eq(true)
      end

      poll = Poll.find_by(name: "testing")

      expect(poll.post_id).to eq(post.id)
      expect(poll.close_at).to eq(nil)
      expect(poll.anonymous_voters).to eq(3)

      expect(poll.regular?).to eq(true)
      expect(poll.open?).to eq(true)
      expect(poll.always?).to eq(true)
      expect(poll.secret?).to eq(true)

      expect(poll.min).to eq(nil)
      expect(poll.max).to eq(nil)
      expect(poll.step).to eq(nil)

      poll_options = PollOption.where(poll: poll).to_a
      expect(poll_options.size).to eq(2)

      option_1 = poll_options.first
      expect(option_1.digest).to eq("e94c09aae2aa071610212a5c5042111b")
      expect(option_1.html).to eq("Yes")
      expect(option_1.anonymous_votes).to eq(1)

      option_2 = poll_options.last
      expect(option_2.digest).to eq("802c50392a68e426d4b26d81ddc5ab33")
      expect(option_2.html).to eq("No")
      expect(option_2.anonymous_votes).to eq(2)
    end
  end
end
