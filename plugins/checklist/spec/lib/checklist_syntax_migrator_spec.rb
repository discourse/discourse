# frozen_string_literal: true

require "rails_helper"

describe ChecklistSyntaxMigrator do
  before { SiteSetting.allow_uncategorized_topics = true }
  let(:topic) { Fabricate(:topic) }
  let(:post_args) { { user: topic.user, topic: topic } }

  def post_with_body(body)
    args = post_args.merge(raw: body)
    Fabricate.build(:post, args)
  end

  it "replaces instances of the old checkbox instance, with the new syntax" do
    body = "[-] 1\n[_] 2\n[*] 3\n[\\*] 4"
    post = post_with_body(body)

    ChecklistSyntaxMigrator.new(post).update_syntax!

    expected = "[x] 1\n[x] 2\n[x] 3\n[x] 4"
    expect(post.reload.raw).to eq(expected)
  end

  it "does not replace if more than 3 spaces are before a checkbox" do
    body = "    [\*]\n      [-]"
    post = post_with_body(body)
    post.save

    ChecklistSyntaxMigrator.new(post).update_syntax!
    expect(post.reload.raw).to eq(body)
  end

  it "does not replace checkboxes after text" do
    body = "what about this? [\*]"
    post = post_with_body(body)
    post.save

    ChecklistSyntaxMigrator.new(post).update_syntax!
    expect(post.reload.raw).to eq(body)
  end

  it "handles each line independently" do
    body = "[-] replace that, \n this wont be changed! [\*]"
    post = post_with_body(body)

    ChecklistSyntaxMigrator.new(post).update_syntax!

    expected = "[x] replace that, \n this wont be changed! [\*]"
    expect(post.reload.raw).to eq(expected)
  end

  it "allows spaces 0,1,2 and 3 spaces before" do
    body = "[-] 0 spaces\n [-] 1 space\n  [-] 2 spaces\n   [-] 3 spaces\n    [-] 4 spaces"
    post = post_with_body(body)

    ChecklistSyntaxMigrator.new(post).update_syntax!

    expected = "[x] 0 spaces\n [x] 1 space\n  [x] 2 spaces\n   [x] 3 spaces\n    [-] 4 spaces"
    expect(post.reload.raw).to eq(expected)
  end

  it "does not convert checkboxes in code blocks" do
    body = [
      "```",
      "[\*] This won't be converted",
      "```",
      "[\*] That will",
      "```",
      "[\*] Again this won't",
      "```",
    ].join("\n")
    post = post_with_body(body)

    ChecklistSyntaxMigrator.new(post).update_syntax!

    expected = [
      "```",
      "[\*] This won't be converted",
      "```",
      "[x] That will",
      "```",
      "[\*] Again this won't",
      "```",
    ].join("\n")
    expect(post.reload.raw).to eq(expected)
  end

  it "does not convert checkboxes in block quotes" do
    body = [
      '[quote="markvanlan, post:10, topic:10"]',
      "[\*] This won't be converted",
      "[/quote]",
      "[\*] That will",
      '[quote="markvanlan, post:11, topic:10"]',
      "[\*] Again this won't",
      "[/quote]",
    ].join("\n")
    post = post_with_body(body)

    ChecklistSyntaxMigrator.new(post).update_syntax!

    expected = [
      '[quote="markvanlan, post:10, topic:10"]',
      "[\*] This won't be converted",
      "[/quote]",
      "[x] That will",
      '[quote="markvanlan, post:11, topic:10"]',
      "[\*] Again this won't",
      "[/quote]",
    ].join("\n")
    expect(post.reload.raw).to eq(expected)
  end
end
