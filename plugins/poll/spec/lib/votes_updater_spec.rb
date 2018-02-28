require 'rails_helper'

describe DiscoursePoll::VotesUpdater do
  let(:target_user) { Fabricate(:user_single_email, username: 'alice', email: 'alice@example.com') }
  let(:source_user) { Fabricate(:user_single_email, username: 'alice1', email: 'alice@work.com') }
  let(:walter) { Fabricate(:walter_white) }

  let(:target_user_id) { target_user.id.to_s }
  let(:source_user_id) { source_user.id.to_s }
  let(:walter_id) { walter.id.to_s }

  let(:post_with_two_polls) do
    raw = <<~RAW
      [poll type=multiple min=2 max=3 public=true]
      - Option 1
      - Option 2
      - Option 3
      [/poll]

      [poll name=private_poll]
      - Option 1
      - Option 2
      - Option 3
      [/poll]
    RAW

    Fabricate(:post, raw: raw)
  end

  let(:option1_id) { "63eb791ab5d08fc4cc855a0703ac0dd1" }
  let(:option2_id) { "773a193533027393806fff6edd6c04f7" }
  let(:option3_id) { "f42f567ca3136ee1322d71d7745084c7" }

  def vote(post, user, option_ids, poll_name = nil)
    poll_name ||= DiscoursePoll::DEFAULT_POLL_NAME
    DiscoursePoll::Poll.vote(post.id, poll_name, option_ids, user)
  end

  it "should move votes to the target_user when only the source_user voted" do
    vote(post_with_two_polls, source_user, [option1_id, option3_id])
    vote(post_with_two_polls, walter, [option1_id, option2_id])

    DiscoursePoll::VotesUpdater.merge_users!(source_user, target_user)
    post_with_two_polls.reload

    polls = post_with_two_polls.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]
    expect(polls["poll"]["options"][0]["votes"]).to eq(2)
    expect(polls["poll"]["options"][1]["votes"]).to eq(1)
    expect(polls["poll"]["options"][2]["votes"]).to eq(1)

    expect(polls["poll"]["options"][0]["voter_ids"]).to contain_exactly(target_user.id, walter.id)
    expect(polls["poll"]["options"][1]["voter_ids"]).to contain_exactly(walter.id)
    expect(polls["poll"]["options"][2]["voter_ids"]).to contain_exactly(target_user.id)

    votes = post_with_two_polls.custom_fields[DiscoursePoll::VOTES_CUSTOM_FIELD]
    expect(votes.keys).to contain_exactly(target_user_id, walter_id)
    expect(votes[target_user_id]["poll"]).to contain_exactly(option1_id, option3_id)
    expect(votes[walter_id]["poll"]).to contain_exactly(option1_id, option2_id)
  end

  it "should delete votes of the source_user if the target_user voted" do
    vote(post_with_two_polls, source_user, [option1_id, option3_id])
    vote(post_with_two_polls, target_user, [option2_id, option3_id])
    vote(post_with_two_polls, walter, [option1_id, option2_id])

    DiscoursePoll::VotesUpdater.merge_users!(source_user, target_user)
    post_with_two_polls.reload

    polls = post_with_two_polls.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]
    expect(polls["poll"]["options"][0]["votes"]).to eq(1)
    expect(polls["poll"]["options"][1]["votes"]).to eq(2)
    expect(polls["poll"]["options"][2]["votes"]).to eq(1)

    expect(polls["poll"]["options"][0]["voter_ids"]).to contain_exactly(walter.id)
    expect(polls["poll"]["options"][1]["voter_ids"]).to contain_exactly(target_user.id, walter.id)
    expect(polls["poll"]["options"][2]["voter_ids"]).to contain_exactly(target_user.id)

    votes = post_with_two_polls.custom_fields[DiscoursePoll::VOTES_CUSTOM_FIELD]
    expect(votes.keys).to contain_exactly(target_user_id, walter_id)
    expect(votes[target_user_id]["poll"]).to contain_exactly(option2_id, option3_id)
    expect(votes[walter_id]["poll"]).to contain_exactly(option1_id, option2_id)
  end

  it "does not add voter_ids unless the poll is public" do
    vote(post_with_two_polls, source_user, [option1_id, option3_id], "private_poll")
    vote(post_with_two_polls, walter, [option1_id, option2_id], "private_poll")

    DiscoursePoll::VotesUpdater.merge_users!(source_user, target_user)
    post_with_two_polls.reload

    polls = post_with_two_polls.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]
    polls["private_poll"]["options"].each { |o| expect(o).to_not have_key("voter_ids") }
  end
end
