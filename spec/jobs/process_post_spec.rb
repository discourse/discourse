require 'spec_helper'
require 'jobs/regular/process_post'

describe Jobs::ProcessPost do

  it "returns when the post cannot be found" do
    lambda { Jobs::ProcessPost.new.perform(post_id: 1, sync_exec: true) }.should_not raise_error
  end

  context 'with a post' do

    let(:post) do
      Fabricate(:post)
    end

    it 'does not erase posts when CookedPostProcessor malfunctions' do
      # Look kids, an actual reason why you want to use mocks
      CookedPostProcessor.any_instance.expects(:html).returns(' ')
      cooked = post.cooked

      post.reload
      post.cooked.should == cooked

      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)
    end

    it 'recooks if needed' do
      cooked = post.cooked

      post.update_columns(cooked: "frogs")
      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)

      post.reload
      post.cooked.should == cooked
    end

    it 'processes posts' do

      post = Fabricate(:post, raw: "<img src='#{Discourse.base_url_no_prefix}/awesome/picture.png'>")
      post.cooked.should =~ /http/

      Jobs::ProcessPost.new.execute(post_id: post.id)
      post.reload

      # subtle but cooked post processor strip this stuff, this ensures all the code gets a workout
      post.cooked.should_not =~ /http/
    end

  end


end
