# encoding: UTF-8
# frozen_string_literal: true

RSpec.describe Topic do
  let(:job_klass) { Jobs::CloseTopic }

  context "when creating a topic without auto-close" do
    let(:topic) { Fabricate(:topic, category: category) }

    context "when uncategorized" do
      let(:category) { nil }

      it "should not schedule the topic to auto-close" do
        expect(topic.public_topic_timer).to eq(nil)
        expect(job_klass.jobs).to eq([])
      end
    end

    context "with category without default auto-close" do
      let(:category) { Fabricate(:category, auto_close_hours: nil) }

      it "should not schedule the topic to auto-close" do
        expect(topic.public_topic_timer).to eq(nil)
        expect(job_klass.jobs).to eq([])
      end
    end

    context "when jobs may be queued" do
      before { freeze_time }

      context "when category has a default auto-close" do
        let(:category) { Fabricate(:category, auto_close_hours: 2.0) }

        it "should schedule the topic to auto-close" do
          topic

          topic_status_update = TopicTimer.last

          expect(topic_status_update.topic).to eq(topic)
          expect(topic.public_topic_timer.execute_at).to be_within_one_second_of(2.hours.from_now)
        end

        context "when topic was created by staff user" do
          let(:admin) { Fabricate(:admin) }
          let(:staff_topic) { Fabricate(:topic, user: admin, category: category) }

          it "should schedule the topic to auto-close" do
            staff_topic

            topic_status_update = TopicTimer.last

            expect(topic_status_update.topic).to eq(staff_topic)
            expect(topic_status_update.execute_at).to be_within_one_second_of(2.hours.from_now)
            expect(topic_status_update.user).to eq(Discourse.system_user)
          end

          context "when topic is closed manually" do
            it "should remove the schedule to auto-close the topic" do
              topic_timer_id = staff_topic.public_topic_timer.id

              staff_topic.update_status("closed", true, admin)

              expect(
                TopicTimer.with_deleted.find(topic_timer_id).deleted_at,
              ).to be_within_one_second_of(Time.zone.now)
            end
          end
        end

        context "when topic was created by a non-staff user" do
          let(:regular_user) { Fabricate(:user) }
          let(:regular_user_topic) { Fabricate(:topic, user: regular_user, category: category) }

          it "should schedule the topic to auto-close" do
            regular_user_topic

            topic_status_update = TopicTimer.last

            expect(topic_status_update.topic).to eq(regular_user_topic)
            expect(topic_status_update.execute_at).to be_within_one_second_of(2.hours.from_now)
            expect(topic_status_update.user).to eq(Discourse.system_user)
          end
        end
      end
    end
  end
end
