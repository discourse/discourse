require 'spec_helper'
require_dependency 'trashable'

describe Trashable do
  # post is trashable, just use it.
  it "works correctly" do
    p1 = Fabricate(:post)
    p2 = Fabricate(:post)

    Post.count.should == 2
    p1.trash!

    Post.count.should == 1

    Post.with_deleted.count.should == 2
  end
end

