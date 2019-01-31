require "rails_helper"

describe Jobs::ClosePoll do
  let(:post) { Fabricate(:post, raw: "[poll]\n- A\n- B\n[/poll]") }

  describe 'missing arguments' do
    it 'should raise the right error' do
      expect do
        Jobs::ClosePoll.new.execute(post_id: post.id)
      end.to raise_error(Discourse::InvalidParameters, "poll_name")

      expect do
        Jobs::ClosePoll.new.execute(poll_name: "poll")
      end.to raise_error(Discourse::InvalidParameters, "post_id")
    end
  end

  it "automatically closes a poll" do
    expect(post.polls.first.closed?).to eq(false)

    Jobs::ClosePoll.new.execute(post_id: post.id, poll_name: "poll")

    expect(post.polls.first.closed?).to eq(true)
  end

end
