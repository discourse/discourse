# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ConvertToPersonalMessage::V1 do
  fab!(:admin)
  fab!(:user)
  fab!(:topic, :topic_with_op)

  def convert(**configuration)
    execute_node(configuration: { "topic_id" => topic.id.to_s, **configuration.stringify_keys })
  end

  it "converts the topic, adding the actor to the message", :aggregate_failures do
    result = convert(actor_username: admin.username)

    expect(topic.reload).to have_attributes(archetype: Archetype.private_message, category_id: nil)
    expect(topic.topic_allowed_users.pluck(:user_id)).to include(admin.id)
    expect(result).to include(
      "changed" => true,
      "topic" => include("id" => topic.id, "archetype" => Archetype.private_message),
    )
    expect(result).to match_node_output_schema(described_class)
  end

  it "reports nothing changed for a personal message" do
    pm = Fabricate(:private_message_post).topic

    result = nil
    expect { result = execute_node(configuration: { "topic_id" => pm.id.to_s }) }.not_to change {
      pm.posts.count
    }

    expect(result).to include("changed" => false)
  end

  it "rejects an actor who can't convert the topic" do
    expect { convert(actor_username: user.username) }.to raise_error(Discourse::InvalidAccess)

    expect(topic.reload.archetype).to eq(Archetype.default)
  end

  it "fails with the converter's error when there would be too many recipients" do
    SiteSetting.max_allowed_message_recipients = 2
    Fabricate(:post, topic:)
    Fabricate(:post, topic:)

    expect { convert }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(I18n.t("topic_converter.too_many_recipients", max: 2))}/,
    )

    expect(topic.reload.archetype).to eq(Archetype.default)
  end

  it "refuses to convert the banner" do
    topic.make_banner!(admin)

    expect { convert }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(node_error_message("banner", scope: "topic_conversion", topic_id: topic.id))}/,
    )

    expect(topic.reload.archetype).to eq(Archetype.banner)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::ConvertToPublicTopic::V1 do
  fab!(:category)
  fab!(:moderator)
  fab!(:pm) { Fabricate(:private_message_post).topic }

  def convert(**configuration)
    execute_node(configuration: { "topic_id" => pm.id.to_s, **configuration.stringify_keys })
  end

  it "converts the personal message into the category", :aggregate_failures do
    result = convert(category_id: category.id)

    expect(pm.reload).to have_attributes(archetype: Archetype.default, category_id: category.id)
    expect(result).to include(
      "changed" => true,
      "topic" => include("id" => pm.id, "category_id" => category.id),
    )
    expect(result).to match_node_output_schema(described_class)
  end

  it "uses Uncategorized without a category" do
    SiteSetting.allow_uncategorized_topics = true

    convert

    expect(pm.reload.category_id).to eq(SiteSetting.uncategorized_category_id)
  end

  it "reports nothing changed for a public topic or the banner", :aggregate_failures do
    regular = Fabricate(:topic_with_op, category:)
    banner = Fabricate(:topic_with_op, category:)
    banner.make_banner!(Discourse.system_user)

    results =
      [regular, banner].map do |topic|
        execute_node(configuration: { "topic_id" => topic.id.to_s, "category_id" => nil })
      end

    expect(results).to all(include("changed" => false))
    expect(banner.reload).to have_attributes(archetype: Archetype.banner, category_id: category.id)
  end

  it "fails with the revision's error when the topic lacks the tags the category requires" do
    required_tag_group = Fabricate(:tag_group, tags: [Fabricate(:tag)])
    category.category_required_tag_groups.create!(tag_group: required_tag_group, min_count: 1)
    pm.topic_allowed_users.create!(user: moderator)

    expect { convert(category_id: category.id, actor_username: moderator.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(required_tag_group.name)}/,
    )

    expect(pm.reload.archetype).to eq(Archetype.private_message)
  end

  it "fails with a fallback message when the revision fails silently" do
    SiteSetting.allow_uncategorized_topics = false

    expect { convert(category_id: SiteSetting.uncategorized_category_id) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(node_error_message("to_public_topic_failed", scope: "topic_conversion", topic_id: pm.id))}/,
    )

    expect(pm.reload.archetype).to eq(Archetype.private_message)
  end

  it "fails for an unknown category" do
    expect { convert(category_id: -999) }.to raise_error(ActiveRecord::RecordNotFound)

    expect(pm.reload.archetype).to eq(Archetype.private_message)
  end
end
