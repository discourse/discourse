# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SendPersonalMessage::V1 do
  fab!(:sender, :admin)
  fab!(:recipient, :user)
  fab!(:second_recipient, :user)

  describe "#execute" do
    it "creates a personal message for the configured recipient", :aggregate_failures do
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "recipient_usernames" => [recipient.username],
              "title" => "Friend group post",
              "raw" => "A friend posted: /t/example/1/1",
              "sender_username" => sender.username,
            },
          )
      end.to change { Topic.where(archetype: Archetype.private_message).count }.by(1)

      topic = Topic.where(archetype: Archetype.private_message).order(:id).last
      post = topic.first_post

      expect(topic.title).to eq("Friend group post")
      expect(post.raw).to eq("A friend posted: /t/example/1/1")
      expect(post.user).to eq(sender)
      expect(topic.allowed_users).to contain_exactly(sender, recipient)
      expect(result["topic"]).to include(
        "id" => topic.id,
        "title" => topic.title,
        "archetype" => Archetype.private_message,
      )
      expect(result["post"]).to include(
        "id" => post.id,
        "topic_id" => topic.id,
        "post_number" => 1,
        "post_url" => post.url,
        "raw" => post.raw,
        "cooked" => post.cooked,
        "user_id" => sender.id,
        "username" => sender.username,
      )
    end

    it "resolves dynamic recipients and message body", :aggregate_failures do
      result =
        execute_node(
          configuration: {
            "recipient_usernames" => "={{ $json.recipients }}",
            "title" => "=New post from @{{ $json.author }}",
            "raw" => "=Link: {{ $json.url }}",
            "sender_username" => "system",
          },
          item: {
            "json" => {
              "recipients" => [recipient.username],
              "author" => "friend",
              "url" => "/t/post/2/1",
            },
          },
        )

      topic = Topic.where(archetype: Archetype.private_message).order(:id).last

      expect(topic.title).to eq("New post from @friend")
      expect(topic.first_post.raw).to eq("Link: /t/post/2/1")
      expect(topic.allowed_users).to contain_exactly(Discourse.system_user, recipient)
      expect(result.dig("post", "user_id")).to eq(Discourse.system_user.id)
    end

    it "accepts dynamic comma-separated recipients", :aggregate_failures do
      execute_node(
        configuration: {
          "recipient_usernames" => "={{ $json.recipient_usernames }}",
          "title" => "Comma separated recipients",
          "raw" => "This should reach both users",
          "sender_username" => sender.username,
        },
        item: {
          "json" => {
            "recipient_usernames" => "#{recipient.username},#{second_recipient.username}",
          },
        },
      )

      topic = Topic.where(archetype: Archetype.private_message).order(:id).last

      expect(topic.title).to eq("Comma separated recipients")
      expect(topic.allowed_users).to contain_exactly(sender, recipient, second_recipient)
    end

    it "raises when no recipients are configured" do
      expect do
        execute_node(
          configuration: {
            "title" => "Missing recipients",
            "raw" => "This should not be created",
          },
        )
      end.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.send_personal_message.no_recipients"),
      )
    end
  end
end
