require 'rails_helper'
require 'jobs/regular/process_post'

describe Jobs::ProcessPost do

  it "returns when the post cannot be found" do
    expect { Jobs::ProcessPost.new.perform(post_id: 1, sync_exec: true) }.not_to raise_error
  end

  context 'with a post' do

    let(:post) { Fabricate(:post) }

    it 'does not erase posts when CookedPostProcessor malfunctions' do
      # Look kids, an actual reason why you want to use mocks
      CookedPostProcessor.any_instance.expects(:html).returns(' ')
      cooked = post.cooked

      post.reload
      expect(post.cooked).to eq(cooked)

      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)
    end

    it 'recooks if needed' do
      cooked = post.cooked

      post.update_columns(cooked: "frogs")
      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)

      post.reload
      expect(post.cooked).to eq(cooked)
    end

    it 'processes posts' do
      post = Fabricate(:post, raw: "<img src='#{Discourse.base_url_no_prefix}/awesome/picture.png'>")
      expect(post.cooked).to match(/http/)

      Jobs::ProcessPost.new.execute(post_id: post.id)
      post.reload

      # subtle but cooked post processor strip this stuff, this ensures all the code gets a workout
      expect(post.cooked).not_to match(/http/)
    end

    it "always re-extracts links on post process" do
      post.update_columns(raw: "sam has a blog at https://samsaffron.com")
      expect { Jobs::ProcessPost.new.execute(post_id: post.id) }.to change { TopicLink.count }.by(1)
    end

    it "extracts links to quoted posts" do
      quoted_post = Fabricate(:post, raw: "This is a post with a link to https://www.discourse.org", post_number: 42)
      post.update_columns(raw: "This quote is the best\n\n[quote=\"#{quoted_post.user.username}, topic:#{quoted_post.topic_id}, post:#{quoted_post.post_number}\"]\n#{quoted_post.excerpt}\n[/quote]")
      # when creating a quote, we also create the reflexion link
      expect { Jobs::ProcessPost.new.execute(post_id: post.id) }.to change { TopicLink.count }.by(2)
    end

    it "extracts links to oneboxed topics" do
      oneboxed_post = Fabricate(:post)
      post.update_columns(raw: "This post is the best\n\n#{oneboxed_post.full_url}")
      # when creating a quote, we also create the reflexion link
      expect { Jobs::ProcessPost.new.execute(post_id: post.id) }.to change { TopicLink.count }.by(2)
    end

    it "works for posts that belong to no existing user" do
      cooked = post.cooked

      post.update_columns(cooked: "frogs", user_id: nil)
      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)
      post.reload
      expect(post.cooked).to eq(cooked)

      post.update_columns(cooked: "frogs", user_id: User.maximum("id") + 1)
      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)
      post.reload
      expect(post.cooked).to eq(cooked)
    end
  end

end
