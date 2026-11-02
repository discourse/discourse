# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::EntitySerializers do
  describe ".serialize_post" do
    fab!(:user)
    fab!(:post) { Fabricate(:post, user: user, raw: "Workflow post body") }

    it "serializes a post for workflow output" do
      result = described_class.serialize_post(post, guardian: user.guardian, include_cooked: true)

      expect(result).to include(
        id: post.id,
        topic_id: post.topic_id,
        topic_title: post.topic.title,
        post_number: post.post_number,
        username: user.username,
        raw: "Workflow post body",
        cooked: post.cooked,
      )
    end

    it "can omit raw and cooked body fields" do
      result =
        described_class.serialize_post(
          post,
          guardian: user.guardian,
          include_raw: false,
          include_cooked: false,
        )

      expect(result).not_to include(:raw, :cooked)
    end

    it "returns nil for a missing post" do
      expect(described_class.serialize_post(nil)).to be_nil
    end
  end

  describe ".serialize_topic" do
    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user: user) }

    it "serializes a topic for workflow output" do
      topic.custom_fields["workflow_key"] = "workflow value"
      topic.custom_fields["other_key"] = "other value"
      topic.save_custom_fields
      result =
        described_class.serialize_topic(
          topic.reload,
          guardian: user.guardian,
          custom_field_names: ["workflow_key"],
        )

      expect(result).to include(
        id: topic.id,
        title: topic.title,
        category_id: topic.category_id,
        custom_fields: {
          workflow_key: "workflow value",
        },
      )
      expect(result[:custom_fields]).not_to include(:other_key)
    end

    it "omits custom fields by default" do
      topic.custom_fields["workflow_key"] = "workflow value"
      topic.save_custom_fields
      result = described_class.serialize_topic(topic, guardian: user.guardian)

      expect(result).not_to include(:custom_fields)
    end
  end
end
