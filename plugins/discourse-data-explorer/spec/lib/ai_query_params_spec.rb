# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::AiQueryParams do
  fab!(:user)

  def sample_for(declaration)
    sql = <<~SQL
      -- [params]
      #{declaration}

      SELECT 1
    SQL
    query = Fabricate(:query, sql: sql)
    described_class.sample_for(query, current_user: user)
  end

  it "returns representative static values for scalar types" do
    result = sample_for(<<~PARAMS)
        -- int :i
        -- boolean :b
        -- string :s
      PARAMS

    expect(result["i"]).to eq("1")
    expect(result["b"]).to eq("true")
    expect(result["s"]).to eq("sample")
  end

  it "uses the current user's username for user types" do
    result = sample_for(<<~PARAMS)
        -- user_id :u
        -- user_list :ul
      PARAMS

    expect(result["u"]).to eq(user.username)
    expect(result["ul"]).to eq(user.username)
  end

  it "samples existing records for id types" do
    Fabricate(:post)
    Fabricate(:category)
    Fabricate(:group)

    result = sample_for(<<~PARAMS)
        -- post_id :p
        -- topic_id :t
        -- category_id :c
        -- group_id :g
        -- group_list :gl
      PARAMS

    expect(Post.where(deleted_at: nil).exists?(id: result["p"])).to eq(true)
    expect(Topic.where(deleted_at: nil).exists?(id: result["t"])).to eq(true)
    expect(Category.where(read_restricted: false).exists?(id: result["c"])).to eq(true)
    expect(Group.exists?(name: result["g"])).to eq(true)
    expect(Group.exists?(name: result["gl"])).to eq(true)
  end

  it "skips soft-deleted posts when sampling post_id" do
    deleted_post = Fabricate(:post)
    live_post = Fabricate(:post)
    deleted_post.trash!

    result = sample_for("-- post_id :p")

    expect(result["p"]).to eq(live_post.id.to_s)
    expect(result["p"]).not_to eq(deleted_post.id.to_s)
  end

  it "does not sample params that declare a default" do
    result = sample_for("-- int :i = 5")

    expect(result).not_to have_key("i")
  end
end
