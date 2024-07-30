# frozen_string_literal: true

describe Jobs::DiscourseAutomation::Tracker do
  before { SiteSetting.discourse_automation_enabled = true }

  describe "pending automation" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: "gift_exchange",
        trigger: DiscourseAutomation::Triggers::POINT_IN_TIME,
      )
    end

    before do
      automation.upsert_field!(
        "giftee_assignment_messages",
        "pms",
        { value: [{ raw: "foo", title: "bar" }] },
        target: "script",
      )
      automation.upsert_field!("gift_exchangers_group", "group", { value: 1 }, target: "script")
    end

    context "when pending automation is in past" do
      before do
        automation.upsert_field!(
          "execute_at",
          "date_time",
          { value: 2.hours.from_now },
          target: "trigger",
        )
      end

      it "consumes the pending automation" do
        freeze_time 4.hours.from_now do
          expect { Jobs::DiscourseAutomation::Tracker.new.execute }.to change {
            automation.pending_automations.count
          }.by(-1)
        end
      end
    end

    context "when pending automation is in future" do
      before do
        automation.upsert_field!(
          "execute_at",
          "date_time",
          { value: 2.hours.from_now },
          target: "trigger",
        )
      end

      it "doesn’t consume the pending automation" do
        expect { Jobs::DiscourseAutomation::Tracker.new.execute }.not_to change {
          automation.pending_automations.count
        }
      end
    end

    it "doesn't run multiple times if the job is invoked multiple times concurrently" do
      count = 0

      DiscourseAutomation::Scriptable.add("no_race_condition") do
        script { count += 1 }

        triggerables [DiscourseAutomation::Triggers::RECURRING]
      end

      automation =
        Fabricate(
          :automation,
          script: "no_race_condition",
          trigger: DiscourseAutomation::Triggers::RECURRING,
        )

      automation.upsert_field!(
        "start_date",
        "date_time",
        { value: 61.minutes.ago },
        target: "trigger",
      )

      automation.upsert_field!(
        "recurrence",
        "period",
        { value: { interval: 1, frequency: "hour" } },
        target: "trigger",
      )

      freeze_time(2.hours.from_now) do
        threads = []
        5.times { threads << Thread.new { Jobs::DiscourseAutomation::Tracker.new.execute } }
        threads.each(&:join)
      end

      expect(count).to eq(1)
    ensure
      DiscourseAutomation::Scriptable.remove("no_race_condition")
    end
  end

  describe "pending pms" do
    before { Jobs.run_later! }

    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::SEND_PMS,
        trigger: DiscourseAutomation::Triggers::TOPIC,
      )
    end

    let!(:pending_pm) do
      automation.pending_pms.create!(
        title: "Il pleure dans mon cœur Comme il pleut sur la ville;",
        raw: "Quelle est cette langueur Qui pénètre mon cœur ?",
        sender: "system",
        execute_at: Time.now,
        target_usernames: ["system"],
      )
    end

    context "when pending pm is in past" do
      before { pending_pm.update!(execute_at: 2.hours.ago) }

      it "consumes the pending pm" do
        expect { Jobs::DiscourseAutomation::Tracker.new.execute }.to change {
          automation.pending_pms.count
        }.by(-1)
      end
    end

    context "when pending pm is in future" do
      before { pending_pm.update!(execute_at: 2.hours.from_now) }

      it "doesn’t consume the pending pm" do
        expect { Jobs::DiscourseAutomation::Tracker.new.execute }.not_to change {
          automation.pending_pms.count
        }
      end
    end

    it "doesn't send multiple messages if the job is invoked multiple times concurrently" do
      pending_pm.update!(execute_at: 1.hour.from_now)
      expect do
        freeze_time(2.hours.from_now) do
          threads = []
          5.times { threads << Thread.new { Jobs::DiscourseAutomation::Tracker.new.execute } }
          threads.each(&:join)
        end
      end.to change { Topic.private_messages_for_user(Discourse.system_user).count }.by(1)
    end
  end
end
