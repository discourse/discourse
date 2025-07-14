# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

RSpec.describe RandomAssignUtils do
  FakeAutomation = Struct.new(:id)

  let!(:automation) { FakeAutomation.new(1) }
  let(:fake_logger) { FakeLogger.new }

  before do
    SiteSetting.assign_enabled = true
    Rails.logger.broadcast_to(fake_logger)
  end

  after { Rails.logger.stop_broadcasting_to(fake_logger) }

  describe ".automation_script!" do
    subject(:auto_assign) { described_class.automation_script!(ctx, fields, automation) }

    fab!(:post_1) { Fabricate(:post) }
    fab!(:topic_1) { post_1.topic }
    fab!(:group_1) { Fabricate(:group) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:user_3) { Fabricate(:user) }

    let(:ctx) { {} }
    let(:fields) { {} }

    before do
      SiteSetting.assign_allowed_on_groups = group_1.id.to_s
      group_1.add(user_1)
    end

    context "when all users of group are on holidays" do
      let(:fields) do
        {
          "assignees_group" => {
            "value" => group_1.id,
          },
          "assigned_topic" => {
            "value" => topic_1.id,
          },
        }
      end

      before { UserCustomField.create!(name: "on_holiday", value: "t", user_id: user_1.id) }

      it "creates post on the topic" do
        auto_assign
        expect(topic_1.posts.last.raw).to match(
          I18n.t("discourse_automation.scriptables.random_assign.no_one", group: group_1.name),
        )
      end
    end

    context "when all users of group have been assigned recently" do
      let(:fields) do
        {
          "assignees_group" => {
            "value" => group_1.id,
          },
          "assigned_topic" => {
            "value" => topic_1.id,
          },
        }
      end

      before do
        group_1.add(user_2)
        group_1.add(user_3)
        freeze_time(10.days.ago) { Assigner.new(topic_1, Discourse.system_user).assign(user_1) }
        freeze_time(5.days.ago) { Assigner.new(topic_1, Discourse.system_user).assign(user_3) }
        Assigner.new(topic_1, Discourse.system_user).assign(user_2)
      end

      it "assigns the least recently assigned user to the topic" do
        expect { auto_assign }.to change { topic_1.reload.assignment.assigned_to }.to(user_1)
      end

      context "when a user is on holiday" do
        before do
          user_1.custom_fields["on_holiday"] = true
          user_1.save!
        end

        it "doesn't assign them" do
          expect { auto_assign }.to change { topic_1.reload.assignment.assigned_to }.to(user_3)
        end
      end
    end

    context "when no users can be assigned because none are members of assign_allowed_on_groups groups" do
      let(:fields) do
        {
          "assignees_group" => {
            "value" => group_1.id,
          },
          "assigned_topic" => {
            "value" => topic_1.id,
          },
        }
      end

      before { SiteSetting.assign_allowed_on_groups = "" }

      it "creates post on the topic" do
        auto_assign
        expect(topic_1.posts.last.raw).to match(
          I18n.t("discourse_automation.scriptables.random_assign.no_one", group: group_1.name),
        )
      end
    end

    context "when user can be assigned" do
      context "when post_template is set" do
        let(:fields) do
          {
            "post_template" => {
              "value" => "this is a post template",
            },
            "assignees_group" => {
              "value" => group_1.id,
            },
            "assigned_topic" => {
              "value" => topic_1.id,
            },
          }
        end

        it "creates a post with the template and assign the user" do
          auto_assign
          expect(topic_1.posts.second.raw).to match("this is a post template")
        end
      end

      context "when post_template is not set" do
        let(:fields) do
          {
            "assignees_group" => {
              "value" => group_1.id,
            },
            "assigned_topic" => {
              "value" => topic_1.id,
            },
          }
        end

        it "assigns the user to the topic" do
          auto_assign
          expect(topic_1.assignment.assigned_to_id).to eq(user_1.id)
        end
      end
    end

    context "when all users are in working hours" do
      let(:fields) do
        {
          "in_working_hours" => {
            "value" => true,
          },
          "assignees_group" => {
            "value" => group_1.id,
          },
          "assigned_topic" => {
            "value" => topic_1.id,
          },
        }
      end

      before do
        freeze_time("2022-10-01 02:00")
        UserOption.find_by(user_id: user_1.id).update(timezone: "Europe/Paris")
      end

      it "assigns the user to the topic" do
        auto_assign
        expect(topic_1.assignment.assigned_to).to eq(user_1)
      end
    end

    context "when in a group of one person" do
      let(:fields) do
        {
          "assignees_group" => {
            "value" => group_1.id,
          },
          "assigned_topic" => {
            "value" => topic_1.id,
          },
        }
      end

      context "when user is already assigned" do
        before { described_class.automation_script!(ctx, fields, automation) }

        it "reassigns them" do
          expect { auto_assign }.to change { topic_1.reload.assignment.id }
          expect(topic_1.assignment.assigned_to).to eq(user_1)
        end
      end
    end

    context "when assignees_group is not provided" do
      let(:fields) { { "assigned_topic" => { "value" => topic_1.id } } }

      it "raises an error" do
        expect { auto_assign }.to raise_error(/`assignees_group` not provided/)
      end
    end

    context "when assignees_group not found" do
      let(:fields) do
        { "assigned_topic" => { "value" => topic_1.id }, "assignees_group" => { "value" => -1 } }
      end

      it "raises an error" do
        expect { auto_assign }.to raise_error(/Group\(-1\) not found/)
      end
    end

    context "when assigned_topic not provided" do
      it "raises an error" do
        expect { auto_assign }.to raise_error(/`assigned_topic` not provided/)
      end
    end

    context "when assigned_topic is not found" do
      let(:fields) do
        { "assigned_topic" => { "value" => -1 }, "assignees_group" => { "value" => group_1.id } }
      end

      it "raises an error" do
        expect { auto_assign }.to raise_error(/Topic\(-1\) not found/)
      end
    end

    context "when minimum_time_between_assignments is set" do
      context "when the topic has been assigned recently" do
        let(:fields) do
          {
            "assignees_group" => {
              "value" => group_1.id,
            },
            "assigned_topic" => {
              "value" => topic_1.id,
            },
            "minimum_time_between_assignments" => {
              "value" => 10,
            },
          }
        end

        before do
          freeze_time
          TopicCustomField.create!(
            name: "assigned_to_id",
            topic_id: topic_1.id,
            created_at: 20.hours.ago,
          )
        end

        it "logs a warning" do
          auto_assign
          expect(Rails.logger.infos.first).to match(
            /Topic\(#{topic_1.id}\) has already been assigned recently/,
          )
        end
      end
    end

    context "when skip_new_users_for_days is set" do
      let(:fields) do
        {
          "assignees_group" => {
            "value" => group_1.id,
          },
          "assigned_topic" => {
            "value" => topic_1.id,
          },
          "skip_new_users_for_days" => {
            "value" => "10",
          },
        }
      end

      it "creates post on the topic if all users are new" do
        auto_assign
        expect(topic_1.posts.last.raw).to match(
          I18n.t("discourse_automation.scriptables.random_assign.no_one", group: group_1.name),
        )
      end

      context "when all users are old" do
        let(:fields) do
          {
            "assignees_group" => {
              "value" => group_1.id,
            },
            "assigned_topic" => {
              "value" => topic_1.id,
            },
            "skip_new_users_for_days" => {
              "value" => "0",
            },
          }
        end

        it "assigns topic" do
          auto_assign
          expect(topic_1.assignment).not_to be_nil
        end
      end
    end
  end

  describe "#recently_assigned_users_ids" do
    subject(:assignees) { utils.recently_assigned_users_ids(2.months.ago) }

    let(:utils) { described_class.new({}, fields, automation) }
    let(:fields) do
      {
        "assignees_group" => {
          "value" => assign_allowed_group.id,
        },
        "assigned_topic" => {
          "value" => post.topic.id,
        },
      }
    end
    let(:post) { Fabricate(:post) }
    let(:assign_allowed_group) { Group.find_by(name: "staff") }

    context "when no one has been assigned" do
      it "returns an empty array" do
        expect(assignees).to be_empty
      end
    end

    context "when users have been assigned" do
      let(:admin) { Fabricate(:admin) }
      let!(:user_1) { Fabricate(:user, groups: [assign_allowed_group]) }
      let!(:user_2) { Fabricate(:user, groups: [assign_allowed_group]) }
      let!(:user_3) { Fabricate(:user, groups: [assign_allowed_group]) }
      let!(:user_4) { Fabricate(:user, groups: [assign_allowed_group]) }
      let(:post_2) { Fabricate(:post, topic: post.topic) }

      before do
        freeze_time 3.months.ago do
          Assigner.new(post.topic, admin).assign(user_3)
        end
        freeze_time 45.days.ago do
          Assigner.new(post_2, admin).assign(user_4)
        end
        freeze_time 30.days.ago do
          Assigner.new(post.topic, admin).assign(user_1)
        end
        freeze_time 15.days.ago do
          Assigner.new(post.topic, admin).assign(user_2)
        end
      end

      it "returns the recently assigned user ids" do
        expect(assignees).to eq([user_2, user_1, user_4].map(&:id))
      end
    end
  end
end
