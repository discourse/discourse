# frozen_string_literal: true

require "rails_helper"

describe TopicEmbed do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:title) { "How to turn a fish from good to evil in 30 seconds" }
  let(:url) { "http://eviltrout.com/123" }
  let(:contents) do
    "<p>hello world new post <a href='/hello'>hello</a> <img src='images/wat.jpg'></p>"
  end
  fab!(:embeddable_host)
  let(:category) { Fabricate(:category) }

  it "creates the topic with the right subtype in a category with `create_as_post_voting_default == true`" do
    category.custom_fields[PostVoting::CREATE_AS_POST_VOTING_DEFAULT] = true
    category.save!

    Jobs.run_immediately!
    imported_post =
      TopicEmbed.import(
        user,
        "http://eviltrout.com/abcd",
        title,
        "some random content",
        category_id: category.id,
      )

    expect(imported_post.topic.category).to eq(category)
    expect(imported_post.topic.subtype).to eq(Topic::POST_VOTING_SUBTYPE)
  end

  it "creates the topic with the right subtype in a category with `only_post_voting_in_this_category == true`" do
    category.custom_fields[PostVoting::ONLY_POST_VOTING_IN_THIS_CATEGORY] = true
    category.save!

    Jobs.run_immediately!
    imported_post =
      TopicEmbed.import(
        user,
        "http://eviltrout.com/abcd",
        title,
        "some random content",
        category_id: category.id,
      )

    expect(imported_post.topic.category).to eq(category)
    expect(imported_post.topic.subtype).to eq(Topic::POST_VOTING_SUBTYPE)
  end

  it "doesn't change the subtype when the category is not set to use post voting by default" do
    Jobs.run_immediately!
    imported_post =
      TopicEmbed.import(
        user,
        "http://eviltrout.com/abcd",
        title,
        "some random content",
        category_id: category.id,
      )

    expect(imported_post.topic.category).to eq(category)
    expect(imported_post.topic.subtype).not_to eq(Topic::POST_VOTING_SUBTYPE)
  end
end
