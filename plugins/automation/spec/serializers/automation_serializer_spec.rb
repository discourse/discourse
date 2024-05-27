# frozen_string_literal: true

describe DiscourseAutomation::AutomationSerializer do
  fab!(:user)
  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scripts::FLAG_POST_ON_WORDS,
      trigger: DiscourseAutomation::Triggers::POST_CREATED_EDITED,
    )
  end

  context "when there are pending automations" do
    before { automation.pending_automations.create!(execute_at: 2.hours.from_now) }

    it "has a next_pending_automation_at field" do
      serializer =
        DiscourseAutomation::AutomationSerializer.new(
          automation,
          scope: Guardian.new(user),
          root: false,
        )
      expect(serializer.next_pending_automation_at).to be_within_one_minute_of(2.hours.from_now)
    end
  end

  context "when has no pending automation" do
    it "doesn’t have a next_pending_automation_at field" do
      serializer =
        DiscourseAutomation::AutomationSerializer.new(
          automation,
          scope: Guardian.new(user),
          root: false,
        )
      expect(serializer.next_pending_automation_at).to_not be
    end
  end

  context "when script with fields limited to a specific trigger" do
    before do
      DiscourseAutomation::Scriptable.add("foo") do
        field :bar, component: :text, triggerable: DiscourseAutomation::Triggers::TOPIC
      end
      I18n.backend.store_translations(
        :en,
        {
          discourse_automation: {
            scriptables: {
              foo: {
                title: "Something about us.",
                description: "We rock!",
              },
            },
          },
        },
      )
    end

    context "when automation is not using the specific trigger" do
      fab!(:automation) do
        Fabricate(
          :automation,
          script: "foo",
          trigger: DiscourseAutomation::Triggers::POST_CREATED_EDITED,
        )
      end

      it "filters the field" do
        serializer =
          DiscourseAutomation::AutomationSerializer.new(
            automation,
            scope: Guardian.new(user),
            root: false,
          )
        expect(serializer.script[:templates]).to eq([])
      end
    end

    context "when automation is using the specific trigger" do
      fab!(:automation) do
        Fabricate(:automation, script: "foo", trigger: DiscourseAutomation::Triggers::TOPIC)
      end

      it "doesn’t filter the field" do
        serializer =
          DiscourseAutomation::AutomationSerializer.new(
            automation,
            scope: Guardian.new(user),
            root: false,
          )
        expect(serializer.script[:templates].length).to eq(1)
        expect(serializer.script[:templates].first[:name]).to eq(:bar)
      end
    end
  end

  describe "#placeholders" do
    before do
      DiscourseAutomation::Scriptable.add("foo_bar") do
        version 1

        placeholder :foo
        placeholder :bar
        placeholder :bar, triggerable: :user_updated
        placeholder :bar, triggerable: :user_updated
        placeholder :bar, triggerable: :something
        placeholder(triggerable: :user_updated) { :cool }
        placeholder(triggerable: :whatever) { :not_cool }
        placeholder { "Why not" }

        triggerables %i[user_updated something whatever]
      end
    end

    fab!(:automation) { Fabricate(:automation, script: :foo_bar, trigger: :user_updated) }

    it "correctly renders placeholders" do
      serializer =
        DiscourseAutomation::AutomationSerializer.new(
          automation,
          scope: Guardian.new(user),
          root: false,
        )

      expect(serializer.placeholders).to eq(%w[foo bar cool why_not])
    end
  end
end
