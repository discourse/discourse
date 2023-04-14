# frozen_string_literal: true

RSpec.describe Trashable do
  # post is trashable, just use it.
  it "works correctly" do
    p1 = Fabricate(:post)
    p2 = Fabricate(:post)

    expect { p1.trash! }.to change { Post.count }.by(-1)
    expect(Post.with_deleted.count).to eq(Post.count + 1)
  end

  it "can list only deleted items" do
    p1 = Fabricate(:post)
    p2 = Fabricate(:post)

    p1.trash!
    expect(Post.only_deleted.count).to eq(1)
    expect(Post.only_deleted.first).to eq(p1)
  end

  it "can recover" do
    p1 = Fabricate(:post)
    p1.trash!
    expect { p1.recover! }.to change { Post.count }.by(1)
    expect(Post.with_deleted.count).to eq(Post.count)
  end
end
