# frozen_string_literal: true

require_relative "write_support"

describe DiscourseMcp::Server, "#call" do
  include_context "with MCP content write rules"

  def error_text(response)
    expect_refusal(response)
    result(response).fetch("content").first.fetch("text")
  end

  it "sanitizes duplicate-title validation without exposing another topic's URL" do
    SiteSetting.allow_duplicate_topic_titles = false
    args = topic_arguments(title: post.topic.title)
    baseline = rpc("discourse_create_topic", args)
    expect(error_text(baseline)).to include("href=", post.topic.url)
    activate!
    response = rpc("discourse_create_topic", args)
    expect([McpContentWriteHelpers::GENERIC_ERROR, "This title is already used"]).to include(
      error_text(response),
    ),
    "SAFE ERROR: duplicate title must use static safe text"
    expect(response.to_json).not_to include(post.topic.url)
  end

  it "sanitizes required-tag-group validation instead of naming its tags and group" do
    author = Fabricate(:user, trust_level: TrustLevel[2])
    author_token = issue_token(author)
    tag = Fabricate(:tag, name: "u4-private-required-tag")
    group = Fabricate(:tag_group, name: "u4-private-required-group", tags: [tag])
    category =
      Fabricate(
        :category,
        category_required_tag_groups: [
          CategoryRequiredTagGroup.new(tag_group: group, min_count: 1),
        ],
      )
    args = topic_arguments(category_id: category.id)
    baseline = rpc("discourse_create_topic", args, access_token: author_token)
    expect(error_text(baseline)).to include(tag.name)
    activate!
    response = rpc("discourse_create_topic", args, access_token: author_token)
    expect(error_text(response)).to eq(McpContentWriteHelpers::GENERIC_ERROR),
    "SAFE ERROR: required-tag-group validation must be content-free"
    expect(response.to_json).not_to include(tag.name, group.name)
  end

  it "sanitizes mutually exclusive tag validation instead of listing other tag names" do
    first = Fabricate(:tag, name: "u4-private-first")
    second = Fabricate(:tag, name: "u4-private-second")
    Fabricate(:tag_group, tags: [first, second], one_per_topic: true)
    args = topic_arguments(tags: [first.name, second.name])
    baseline = rpc("discourse_create_topic", args)
    expect(error_text(baseline)).to include(first.name, second.name)
    activate!
    response = rpc("discourse_create_topic", args)
    expect(error_text(response)).to eq(McpContentWriteHelpers::GENERIC_ERROR),
    "SAFE ERROR: exclusive-tag validation must be content-free"
    expect(response.to_json).not_to include(first.name, second.name)
  end

  it "sanitizes a required custom-field validation naming another record" do
    field = Fabricate(:user_field, name: "u4-private-profile-prompt", requirement: "on_signup")
    args = {
      username: "u4validation",
      email: "u4validation@example.com",
      name: "Garden writer",
      password: "verylongpassword738!",
    }
    baseline = rpc("discourse_create_user", args)
    expect(error_text(baseline)).to include(field.name)
    activate!
    response = rpc("discourse_create_user", args)
    expect(error_text(response)).to eq(McpContentWriteHelpers::GENERIC_ERROR),
    "SAFE ERROR: custom-field validation must be content-free"
    expect(response.to_json).not_to include(field.name)
  end

  it "preserves a typed content-free confirmation error rather than hiding every error" do
    category = Fabricate(:category)
    args = { category_id: category.id, expected_name: category.name, confirm: false }
    baseline = rpc("discourse_delete_category", args)
    expect(error_text(baseline)).to eq(I18n.t("mcp.errors.category_delete_confirmation_required"))
    activate!
    expect(rpc("discourse_delete_category", args)).to eq(baseline)
  end

  it "refuses deletion of a populated category without naming or linking its oldest topic" do
    category = allowed_category
    category.update_column(:topic_count, 1)
    args = { category_id: category.id, expected_name: category.name, confirm: true }
    baseline = rpc("discourse_delete_category", args)
    expect(baseline["status"]).to eq(403)
    activate!
    response = rpc("discourse_delete_category", args)
    expect(response).to eq(baseline)
    expect(response.to_json).not_to include(post.topic.title, post.topic.url)
    expect(Category.exists?(category.id)).to eq(true)
  end
end
