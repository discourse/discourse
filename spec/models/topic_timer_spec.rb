# frozen_string_literal: true

RSpec.describe TopicTimer, type: :model do
  fab!(:topic_timer)
  fab!(:topic)
  fab!(:admin)

  before { freeze_time }

  describe "Validations" do
    describe "pending_timers scope" do
      it "does not return deleted timers" do
        topic_timer.trash!
        expect(TopicTimer.pending_timers.pluck(:id)).not_to include(topic_timer.id)
      end

      it "does not return timers in the future of the provided before time" do
        topic_timer.update!(execute_at: 3.days.from_now)
        expect(TopicTimer.pending_timers.pluck(:id)).not_to include(topic_timer.id)
        expect(TopicTimer.pending_timers(2.days.from_now).pluck(:id)).not_to include(topic_timer.id)
        topic_timer.update!(execute_at: 1.minute.ago, created_at: 10.minutes.ago)
        expect(TopicTimer.pending_timers.pluck(:id)).to include(topic_timer.id)
      end

      describe "duration values" do
        it "does not allow durations <= 0" do
          topic_timer.duration_minutes = -1
          topic_timer.save
          expect(topic_timer.errors.full_messages.first).to include(
            "Duration minutes must be greater than 0.",
          )
        end

        it "does not allow crazy big durations (20 years in minutes)" do
          topic_timer.duration_minutes = 21.years.to_i / 60
          topic_timer.save
          expect(topic_timer.errors.full_messages.first).to include(
            "Duration minutes cannot be more than 20 years.",
          )
        end
      end
    end

    describe "#status_type" do
      it "should ensure that only one active public topic status update exists" do
        topic_timer.update!(topic: topic)
        Fabricate(:topic_timer, deleted_at: Time.zone.now, topic: topic)

        expect { Fabricate(:topic_timer, topic: topic) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe "#execute_at" do
      describe "when #execute_at is greater than #created_at" do
        it "should be valid" do
          topic_timer =
            Fabricate.build(
              :topic_timer,
              execute_at: Time.zone.now + 1.hour,
              user: Fabricate(:user),
              topic: Fabricate(:topic),
            )

          expect(topic_timer).to be_valid
        end
      end

      describe "when #execute_at is smaller than #created_at" do
        it "should not be valid" do
          topic_timer =
            Fabricate.build(
              :topic_timer,
              execute_at: Time.zone.now - 1.hour,
              created_at: Time.zone.now,
              user: Fabricate(:user),
              topic: Fabricate(:topic),
            )

          expect(topic_timer).to_not be_valid
        end
      end
    end

    describe "#category_id" do
      describe "when #status_type is publish_to_category" do
        describe "when #category_id is not present" do
          it "should not be valid" do
            topic_timer =
              Fabricate.build(:topic_timer, status_type: TopicTimer.types[:publish_to_category])

            expect(topic_timer).to_not be_valid
            expect(topic_timer.errors).to include(:category_id)
          end
        end

        describe "when #category_id is present" do
          it "should be valid" do
            topic_timer =
              Fabricate.build(
                :topic_timer,
                status_type: TopicTimer.types[:publish_to_category],
                category_id: Fabricate(:category).id,
                user: Fabricate(:user),
                topic: Fabricate(:topic),
              )

            expect(topic_timer).to be_valid
          end
        end
      end
    end
  end

  describe "Callbacks" do
    describe "when #execute_at and #user_id are not changed" do
      it "should not schedule another to update topic" do
        Jobs.expects(:enqueue_at).never

        topic_timer.update!(topic: Fabricate(:topic))
      end
    end

    describe "when a open topic status update is created for an open topic" do
      fab!(:topic) { Fabricate(:topic, closed: false) }
      fab!(:topic_timer) do
        Fabricate(:topic_timer, status_type: described_class.types[:open], topic: topic)
      end

      before { Jobs.run_immediately! }

      it "should close the topic" do
        topic_timer.send(:schedule_auto_open_job)
        expect(topic.reload.closed).to eq(true)
      end
    end

    describe "when a close topic status update is created for a closed topic" do
      fab!(:topic) { Fabricate(:topic, closed: true) }
      fab!(:topic_timer) do
        Fabricate(:topic_timer, status_type: described_class.types[:close], topic: topic)
      end

      before { Jobs.run_immediately! }

      it "should open the topic" do
        topic_timer.send(:schedule_auto_close_job)
        expect(topic.reload.closed).to eq(false)
      end
    end

    describe "#public_type" do
      %i[close open delete].each do |public_type|
        it "is true for #{public_type}" do
          timer = Fabricate(:topic_timer, status_type: described_class.types[public_type])
          expect(timer.public_type).to eq(true)
        end
      end

      it "is true for publish_to_category" do
        timer =
          Fabricate(
            :topic_timer,
            status_type: described_class.types[:publish_to_category],
            category: Fabricate(:category),
          )
        expect(timer.public_type).to eq(true)
      end

      described_class.private_types.keys.each do |private_type|
        it "is false for #{private_type}" do
          timer = Fabricate(:topic_timer, status_type: described_class.types[private_type])
          expect(timer.public_type).to be_falsey
        end
      end
    end
  end

  describe "runnable?" do
    it "returns false if execute_at > now" do
      topic_timer =
        Fabricate.build(
          :topic_timer,
          execute_at: Time.zone.now + 1.hour,
          user: Fabricate(:user),
          topic: Fabricate(:topic),
        )

      expect(topic_timer.runnable?).to eq(false)
    end

    it "returns false if timer is deleted" do
      topic_timer =
        Fabricate.create(
          :topic_timer,
          execute_at: Time.zone.now - 1.hour,
          created_at: Time.zone.now - 2.hour,
          user: Fabricate(:user),
          topic: Fabricate(:topic),
        )
      topic_timer.trash!

      expect(topic_timer.runnable?).to eq(false)
    end

    it "returns true if execute_at < now" do
      topic_timer =
        Fabricate.build(
          :topic_timer,
          execute_at: Time.zone.now - 1.hour,
          created_at: Time.zone.now - 2.hour,
          user: Fabricate(:user),
          topic: Fabricate(:topic),
        )

      expect(topic_timer.runnable?).to eq(true)
    end
  end
end
