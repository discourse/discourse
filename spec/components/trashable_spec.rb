require 'rails_helper'
require_dependency 'trashable'

describe Trashable do
  # post is trashable, just use it.
  it "works correctly" do
    p1 = Fabricate(:post)
    p2 = Fabricate(:post)

    expect { p1.trash! }.to change{Post.count}.by(-1)
    expect(Post.with_deleted.count).to eq(Post.count + 1)
  end
end

