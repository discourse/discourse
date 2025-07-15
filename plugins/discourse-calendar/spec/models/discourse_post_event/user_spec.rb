# frozen_string_literal: true

describe User do
  Event = DiscoursePostEvent::Event

  before do
    freeze_time DateTime.parse("2020-04-24 14:10")
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe "#can_act_on_discourse_post_event?" do
    context "when user is staff" do
      let(:user_1) { Fabricate(:user, admin: true) }
      let(:user_2) { Fabricate(:user, admin: true) }
      let(:topic_1) { Fabricate(:topic, user: user_2) }
      let(:post_1) { Fabricate(:post, topic: topic_1, user: user_2) }
      let(:post_event_1) { Fabricate(:event, post: post_1) }

      it "can act on the event" do
        expect(user_1.can_act_on_discourse_post_event?(post_event_1)).to eq(true)
      end
    end

    context "when user is not staff" do
      let(:user_1) { Fabricate(:user, refresh_auto_groups: true) }

      context "when user is in list of allowed groups" do
        let(:group_1) do
          Fabricate(:group).tap do |g|
            g.add(user_1)
            g.save!
          end
        end

        before { SiteSetting.discourse_post_event_allowed_on_groups = group_1.id }

        context "when user created the event" do
          let(:topic_1) { Fabricate(:topic, user: user_1) }
          let(:post_1) { Fabricate(:post, topic: topic_1, user: user_1) }
          let(:post_event_1) { Fabricate(:event, post: post_1) }

          it "can act on the event" do
            expect(user_1.can_act_on_discourse_post_event?(post_event_1)).to eq(true)
          end
        end

        context "when allowed group is 'everyone'" do
          let(:topic_1) { Fabricate(:topic, user: user_1) }
          let(:post_1) { Fabricate(:post, topic: topic_1, user: user_1) }
          let(:post_event_1) { Fabricate(:event, post: post_1) }

          it "can act on the event" do
            SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:everyone]
            expect(user_1.can_act_on_discourse_post_event?(post_event_1)).to eq(true)
          end
        end

        context "when user didn’t create the event" do
          let(:user_2) { Fabricate(:user) }
          let(:topic_1) { Fabricate(:topic, user: user_2) }
          let(:post_1) { Fabricate(:post, topic: topic_1, user: user_2) }
          let(:post_event_1) { Fabricate(:event, post: post_1) }

          it "cannot act on the event" do
            expect(user_1.can_act_on_discourse_post_event?(post_event_1)).to eq(false)
          end
        end

        context "when user didn’t create the event, but is allowed to edit the post" do
          let(:user_2) { Fabricate(:user) }
          let(:topic_1) { Fabricate(:topic, user: user_2) }
          let(:post_1) { Fabricate(:post, topic: topic_1, user: user_2) }
          let(:post_event_1) { Fabricate(:event, post: post_1) }
          before do
            user_1.update(trust_level: 4)
            Group.refresh_automatic_groups!
          end

          it "can act on the event" do
            expect(user_1.can_act_on_discourse_post_event?(post_event_1)).to eq(true)
          end
        end
      end

      context "when user is not in list of allowed groups" do
        let(:topic_1) { Fabricate(:topic, user: user_1) }
        let(:post_1) { Fabricate(:post, topic: topic_1, user: user_1) }
        let(:post_event_1) { Fabricate(:event, post: post_1) }

        it "cannot act on the event" do
          expect(user_1.can_act_on_discourse_post_event?(post_event_1)).to eq(false)
        end
      end
    end
  end
end
