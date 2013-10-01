require 'spec_helper'
require 'jobs/regular/process_post'

describe Jobs::ProcessPost do

  it "returns when the post cannot be found" do
    lambda { Jobs::ProcessPost.new.perform(post_id: 1, sync_exec: true) }.should_not raise_error
  end

  context 'with a post' do

    before do
      @post = Fabricate(:post)
    end

    it 'calls process on a CookedPostProcessor' do
      CookedPostProcessor.any_instance.expects(:post_process).once
      Jobs::ProcessPost.new.execute(post_id: @post.id)
    end

    it 'updates the html if the dirty flag is true' do
      CookedPostProcessor.any_instance.expects(:dirty?).returns(true)
      CookedPostProcessor.any_instance.expects(:html).returns('test')
      Post.any_instance.expects(:update_column).with(:cooked, 'test').once
      Jobs::ProcessPost.new.execute(post_id: @post.id)
    end

    it "doesn't update the cooked content if dirty is false" do
      CookedPostProcessor.any_instance.expects(:dirty?).returns(false)
      Post.any_instance.expects(:update_column).never
      Jobs::ProcessPost.new.execute(post_id: @post.id)
    end

  end


end
