# frozen_string_literal: true

describe AdminUserActionSerializer do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  let(:guardian) { Guardian.new(admin) }

  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  it "includes the slug/title/category ID for a post's deleted topic" do
    topic.trash!

    json = AdminUserActionSerializer.new(post, scope: guardian, root: false).as_json

    expect(json[:slug]).to eq(topic.slug)
    expect(json[:title]).to eq(topic.title)
    expect(json[:category_id]).to eq(topic.category_id)
  end
end
