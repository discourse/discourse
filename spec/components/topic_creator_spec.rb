# frozen_string_literal: true

require 'rails_helper'

describe TopicCreator do
  fab!(:user)      { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:admin)     { Fabricate(:admin) }

  let(:valid_attrs) { Fabricate.attributes_for(:topic) }
  let(:pm_valid_attrs)  { { raw: 'this is a new post', title: 'this is a new title', archetype: Archetype.private_message, target_usernames: moderator.username } }

  let(:pm_to_email_valid_attrs) do
    {
      raw: 'this is a new email',
      title: 'this is a new subject',
      archetype: Archetype.private_message,
      target_emails: 'moderator@example.com'
    }
  end

  describe '#create' do
    context 'topic success cases' do
      before do
        TopicCreator.any_instance.expects(:save_topic).returns(true)
        TopicCreator.any_instance.expects(:watch_topic).returns(true)
        SiteSetting.allow_duplicate_topic_titles = true
      end

      it "should be possible for an admin to create a topic" do
        expect(TopicCreator.create(admin, Guardian.new(admin), valid_attrs)).to be_valid
      end

      it "should be possible for a moderator to create a topic" do
        expect(TopicCreator.create(moderator, Guardian.new(moderator), valid_attrs)).to be_valid
      end

      it "supports both meta_data and custom_fields" do
        opts = valid_attrs.merge(
          meta_data: { import_topic_id: "foo" },
          custom_fields: { import_id: "bar" }
        )

        topic = TopicCreator.create(admin, Guardian.new(admin), opts)

        expect(topic.custom_fields["import_topic_id"]).to eq("foo")
        expect(topic.custom_fields["import_id"]).to eq("bar")
      end

      context 'regular user' do
        before { SiteSetting.min_trust_to_create_topic = TrustLevel[0] }

        it "should be possible for a regular user to create a topic" do
          expect(TopicCreator.create(user, Guardian.new(user), valid_attrs)).to be_valid
        end

        it "should be possible for a regular user to create a topic with blank auto_close_time" do
          expect(TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(auto_close_time: ''))).to be_valid
        end

        it "ignores auto_close_time without raising an error" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(auto_close_time: '24'))
          expect(topic).to be_valid
          expect(topic.public_topic_timer).to eq(nil)
        end

        it "can create a topic in a category" do
          category = Fabricate(:category, name: "Neil's Blog")
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(category: category.id))
          expect(topic).to be_valid
          expect(topic.category).to eq(category)
        end

        it "ignores participant_count without raising an error" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(participant_count: 3))
          expect(topic.participant_count).to eq(1)
        end

        it "accepts participant_count in import mode" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(import_mode: true, participant_count: 3))
          expect(topic.participant_count).to eq(3)
        end
      end
    end

    context 'tags' do
      fab!(:tag1) { Fabricate(:tag, name: "fun") }
      fab!(:tag2) { Fabricate(:tag, name: "fun2") }

      before do
        SiteSetting.tagging_enabled = true
        SiteSetting.min_trust_to_create_tag = 0
        SiteSetting.min_trust_level_to_tag_topics = 0
      end

      context 'regular tags' do
        it "user can add tags to topic" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(tags: [tag1.name]))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(1)
        end
      end

      context 'staff-only tags' do
        before do
          create_staff_only_tags(['alpha'])
        end

        it "regular users can't add staff-only tags" do
          expect do
            TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(tags: ['alpha']))
          end.to raise_error(ActiveRecord::Rollback)
        end

        it 'staff can add staff-only tags' do
          topic = TopicCreator.create(admin, Guardian.new(admin), valid_attrs.merge(tags: ['alpha']))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(1)
        end
      end

      context 'minimum_required_tags is present' do
        fab!(:category) { Fabricate(:category, name: "beta", minimum_required_tags: 2) }

        it "fails for regular user if minimum_required_tags is not satisfied" do
          expect(
            TopicCreator.new(user, Guardian.new(user), valid_attrs.merge(category: category.id)).valid?
          ).to be_falsy
        end

        it "lets admin create a topic regardless of minimum_required_tags" do
          topic = TopicCreator.create(admin, Guardian.new(admin), valid_attrs.merge(tags: [tag1.name], category: category.id))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(1)
        end

        it "works for regular user if minimum_required_tags is satisfied" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(tags: [tag1.name, tag2.name], category: category.id))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(2)
        end

        it "minimum_required_tags is satisfying for new tags if user can create" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(tags: ["new tag", "another tag"], category: category.id))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(2)
        end

        it "lets new user create a topic if they don't have sufficient trust level to tag topics" do
          SiteSetting.min_trust_level_to_tag_topics = 1
          new_user = Fabricate(:newuser)
          topic = TopicCreator.create(new_user, Guardian.new(new_user), valid_attrs.merge(category: category.id))
          expect(topic).to be_valid
        end
      end

      context 'required tag group' do
        fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1]) }
        fab!(:category) { Fabricate(:category, name: "beta", required_tag_group: tag_group, min_tags_from_required_group: 1) }

        it "when no tags are not present" do
          expect(
            TopicCreator.new(user, Guardian.new(user), valid_attrs.merge(category: category.id)).valid?
          ).to be_falsy
        end

        it "when tags are not part of the tag group" do
          expect(
            TopicCreator.new(user, Guardian.new(user), valid_attrs.merge(category: category.id, tags: ['nope'])).valid?
          ).to be_falsy
        end

        it "when requirement is met" do
          expect(
            TopicCreator.new(user, Guardian.new(user), valid_attrs.merge(category: category.id, tags: [tag1.name, tag2.name])).valid?
          ).to be_truthy
        end

        it "lets staff ignore the restriction" do
          expect(
            TopicCreator.new(user, Guardian.new(admin), valid_attrs.merge(category: category.id)).valid?
          ).to be_truthy
        end
      end
    end

    context 'personal message' do

      context 'success cases' do
        before do
          TopicCreator.any_instance.expects(:save_topic).returns(true)
          TopicCreator.any_instance.expects(:watch_topic).returns(true)
          SiteSetting.allow_duplicate_topic_titles = true
          SiteSetting.enable_staged_users = true
        end

        it "should be possible for a regular user to send private message" do
          expect(TopicCreator.create(user, Guardian.new(user), pm_valid_attrs)).to be_valid
        end

        it "min_trust_to_create_topic setting should not be checked when sending private message" do
          SiteSetting.min_trust_to_create_topic = TrustLevel[4]
          expect(TopicCreator.create(user, Guardian.new(user), pm_valid_attrs)).to be_valid
        end

        it "enable_personal_messages setting should not be checked when sending private message to staff via flag" do
          SiteSetting.enable_personal_messages = false
          SiteSetting.min_trust_to_send_messages = TrustLevel[4]
          expect(TopicCreator.create(user, Guardian.new(user), pm_valid_attrs.merge(subtype: TopicSubtype.notify_moderators))).to be_valid
        end
      end

      context 'failure cases' do
        it "should be rollback the changes when email is invalid" do
          SiteSetting.manual_polling_enabled = true
          SiteSetting.reply_by_email_address = "sam+%{reply_key}@sam.com"
          SiteSetting.reply_by_email_enabled = true
          SiteSetting.min_trust_to_send_email_messages = TrustLevel[1]
          attrs = pm_to_email_valid_attrs.dup
          attrs[:target_emails] = "t" * 256

          expect do
            TopicCreator.create(user, Guardian.new(user), attrs)
          end.to raise_error(ActiveRecord::Rollback)
        end

        it "min_trust_to_send_messages setting should be checked when sending private message" do
          SiteSetting.min_trust_to_send_messages = TrustLevel[4]

          expect do
            TopicCreator.create(user, Guardian.new(user), pm_valid_attrs)
          end.to raise_error(ActiveRecord::Rollback)
        end
      end

      context 'to emails' do
        it 'works for staff' do
          SiteSetting.min_trust_to_send_email_messages = 'staff'
          expect(TopicCreator.create(admin, Guardian.new(admin), pm_to_email_valid_attrs)).to be_valid
        end

        it 'work for trusted users' do
          SiteSetting.min_trust_to_send_email_messages = 3
          user.update!(trust_level: 3)
          expect(TopicCreator.create(user, Guardian.new(user), pm_to_email_valid_attrs)).to be_valid
        end

        it 'does not work for non-staff' do
          SiteSetting.min_trust_to_send_email_messages = 'staff'
          expect { TopicCreator.create(user, Guardian.new(user), pm_to_email_valid_attrs) }.to raise_error(ActiveRecord::Rollback)
        end

        it 'does not work for untrusted users' do
          SiteSetting.min_trust_to_send_email_messages = 3
          user.update!(trust_level: 2)
          expect { TopicCreator.create(user, Guardian.new(user), pm_to_email_valid_attrs) }.to raise_error(ActiveRecord::Rollback)
        end
      end
    end

    context 'setting timestamps' do
      it 'supports Time instances' do
        freeze_time

        topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(
          created_at: 1.week.ago,
          pinned_at: 3.days.ago
        ))

        expect(topic.created_at).to eq_time(1.week.ago)
        expect(topic.pinned_at).to eq_time(3.days.ago)
      end

      it 'supports strings' do
        freeze_time

        time1 = Time.zone.parse('2019-09-02')
        time2 = Time.zone.parse('2020-03-10 15:17')

        topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(
          created_at: '2019-09-02',
          pinned_at: '2020-03-10 15:17'
        ))

        expect(topic.created_at).to eq_time(time1)
        expect(topic.pinned_at).to eq_time(time2)
      end
    end

    context 'external_id' do
      it 'adds external_id' do
        topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(
          external_id: 'external_id'
        ))

        expect(topic.external_id).to eq('external_id')
      end
    end
  end
end
