# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

RSpec.describe TopicListSerializer do
  fab!(:user)

  let(:private_message_topic) do
    topic =
      Fabricate(
        :private_message_topic,
        topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
      )
    topic.posts << Fabricate(:post)
    topic
  end

  let(:assigned_topic) do
    topic =
      Fabricate(
        :private_message_topic,
        topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
      )

    topic.posts << Fabricate(:post)

    Assigner.new(topic, user).assign(user)
    topic
  end

  let(:guardian) { Guardian.new(user) }
  let(:serializer) { TopicListSerializer.new(topic_list, scope: guardian) }

  include_context "with group that is allowed to assign"

  before do
    SiteSetting.assign_enabled = true
    add_to_assign_allowed_group(user)
  end

  describe "#assigned_messages_count" do
    let(:topic_list) do
      TopicQuery.new(user, assigned: user.username).list_private_messages_assigned(user)
    end

    before { assigned_topic }

    it "should include right attribute" do
      expect(serializer.as_json[:topic_list][:assigned_messages_count]).to eq(1)
    end

    describe "when not viewing assigned list" do
      let(:topic_list) { TopicQuery.new(user).list_private_messages_assigned(user) }

      describe "as an admin user" do
        let(:guardian) { Guardian.new(Fabricate(:admin)) }

        it "should not include the attribute" do
          expect(serializer.as_json[:topic_list][:assigned_messages_count]).to eq(nil)
        end
      end

      describe "as an anon user" do
        let(:guardian) { Guardian.new }

        it "should not include the attribute" do
          expect(serializer.as_json[:topic_list][:assigned_messages_count]).to eq(nil)
        end
      end
    end

    describe "viewing another user" do
      describe "as an anon user" do
        let(:guardian) { Guardian.new }

        it "should not include the attribute" do
          expect(serializer.as_json[:topic_list][:assigned_messages_count]).to eq(nil)
        end
      end

      describe "as a staff" do
        let(:admin) { Fabricate(:admin) }
        let(:guardian) { Guardian.new(admin) }

        it "should include the right attribute" do
          expect(serializer.as_json[:topic_list][:assigned_messages_count]).to eq(1)
        end
      end

      describe "as a normal user" do
        let(:guardian) { Guardian.new(Fabricate(:user)) }

        it "should not include the attribute" do
          expect(serializer.as_json[:topic_list][:assigned_messages_count]).to eq(nil)
        end
      end
    end
  end
end
