# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::Matcher::Strategies::NaturalKey, :rails do
  subject(:strategy) { described_class.new }

  it "finds users by username and tags by name" do
    user = Fabricate(:user, username: "Gerhard")
    tag = Fabricate(:tag, name: "release")

    expect(strategy.keys_for(:user, user)).to eq("username" => "Gerhard")
    expect(strategy.keys_for(:tag, tag)).to eq("name" => "release")

    expect(strategy.find_id(:user, "username" => "gerhard")).to eq(user.id)
    expect(strategy.find_id(:tag, "name" => "Release")).to eq(tag.id)
    expect(strategy.find_id(:user, "username" => "")).to be_nil
    expect(strategy.find_id(:tag, {})).to be_nil
  end

  it "leaves topics and posts to the caller" do
    post = Fabricate(:post)

    expect(strategy.keys_for(:topic, post.topic)).to eq({})
    expect(strategy.keys_for(:post, post)).to eq("post_number" => post.post_number)
    expect(strategy.find_id(:topic, {})).to be_nil
    expect(strategy.find_id(:post, "post_number" => 1)).to be_nil
  end
end
