require 'rails_helper'

describe TopicCreator do

  let(:user)      { Fabricate(:user, trust_level: TrustLevel[2]) }
  let(:moderator) { Fabricate(:moderator) }
  let(:admin)     { Fabricate(:admin) }

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

        it "category name is case insensitive" do
          category = Fabricate(:category, name: "Neil's Blog")
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(category: "neil's blog"))
          expect(topic).to be_valid
          expect(topic.category).to eq(category)
        end
      end
    end

    context 'tags' do
      let!(:tag1) { Fabricate(:tag, name: "fun") }
      let!(:tag2) { Fabricate(:tag, name: "fun2") }

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
          create_staff_tags(['alpha'])
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
        let!(:category) { Fabricate(:category, name: "beta", minimum_required_tags: 2) }

        it "fails for regular user if minimum_required_tags is not satisfied" do
          expect do
            TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(category: "beta"))
          end.to raise_error(ActiveRecord::Rollback)
        end

        it "lets admin create a topic regardless of minimum_required_tags" do
          topic = TopicCreator.create(admin, Guardian.new(admin), valid_attrs.merge(tags: [tag1.name], category: "beta"))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(1)
        end

        it "works for regular user if minimum_required_tags is satisfied" do
          topic = TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(tags: [tag1.name, tag2.name], category: "beta"))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(2)
        end

        it "lets new user create a topic if they don't have sufficient trust level to tag topics" do
          SiteSetting.min_trust_level_to_tag_topics = 1
          new_user = Fabricate(:newuser)
          topic = TopicCreator.create(new_user, Guardian.new(new_user), valid_attrs.merge(category: "beta"))
          expect(topic).to be_valid
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

        it "should be possible for a trusted user to send private messages via email" do
          SiteSetting.manual_polling_enabled = true
          SiteSetting.reply_by_email_address = "sam+%{reply_key}@sam.com"
          SiteSetting.reply_by_email_enabled = true
          SiteSetting.enable_personal_email_messages = true
          SiteSetting.min_trust_to_send_email_messages = TrustLevel[1]

          expect(TopicCreator.create(user, Guardian.new(user), pm_to_email_valid_attrs)).to be_valid
        end
      end

      context 'failure cases' do
        it "should be rollback the changes when email is invalid" do
          SiteSetting.manual_polling_enabled = true
          SiteSetting.reply_by_email_address = "sam+%{reply_key}@sam.com"
          SiteSetting.reply_by_email_enabled = true
          SiteSetting.enable_personal_email_messages = true
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

        it "min_trust_to_send_email_messages should be checked when sending private messages via email" do
          SiteSetting.min_trust_to_send_email_messages = TrustLevel[4]

          expect do
            TopicCreator.create(user, Guardian.new(user), pm_to_email_valid_attrs)
          end.to raise_error(ActiveRecord::Rollback)
        end
      end
    end
  end
end
