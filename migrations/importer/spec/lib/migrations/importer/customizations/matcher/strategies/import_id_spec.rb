# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::Matcher::Strategies::ImportId, :rails do
  subject(:strategy) { described_class.new }

  it "finds topics, posts and users by their import_id custom field" do
    post = Fabricate(:post)
    user = Fabricate(:user)
    TopicCustomField.create!(topic_id: post.topic_id, name: "import_id", value: "t-1")
    PostCustomField.create!(post_id: post.id, name: "import_id", value: "p-1")
    UserCustomField.create!(user_id: user.id, name: "import_id", value: "u-1")

    expect(strategy.keys_for(:topic, post.topic)).to eq("import_id" => "t-1")
    expect(strategy.keys_for(:post, post)).to eq("import_id" => "p-1")
    expect(strategy.keys_for(:user, user)).to eq("import_id" => "u-1")

    expect(strategy.find_id(:topic, "import_id" => "t-1")).to eq(post.topic_id)
    expect(strategy.find_id(:post, "import_id" => "p-1")).to eq(post.id)
    expect(strategy.find_id(:user, "import_id" => "u-1")).to eq(user.id)
    expect(strategy.find_id(:user, "import_id" => "nope")).to be_nil
  end

  it "has nothing for tags and rejects unknown kinds" do
    tag = Fabricate(:tag)

    expect(strategy.keys_for(:tag, tag)).to eq({})
    expect(strategy.find_id(:tag, "import_id" => "1")).to be_nil
    expect { strategy.keys_for(:badge, tag) }.to raise_error(ArgumentError)
  end
end
