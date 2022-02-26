# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::Scriptable do
  before do
    DiscourseAutomation::Scriptable.add('cats_everywhere') do
      version 1

      placeholder :foo
      placeholder :bar

      field :cat, component: :text
      field :dog, component: :text, accepts_placeholders: true
      field :bird, component: :text, triggerable: 'recurring'

      script do
        p 'script'
      end

      on_reset do
        p 'on_reset'
      end
    end

    DiscourseAutomation::Triggerable.add('dog') do
      field :kind, component: :text
    end

    DiscourseAutomation::Scriptable.add('only_dogs') do
      triggerable! :dog, { kind: 'good_boy' }
    end
  end

  fab!(:automation) {
    Fabricate(
      :automation,
      script: 'cats_everywhere',
      trigger: DiscourseAutomation::Triggerable::TOPIC
    )
  }

  describe '#fields' do
    it 'returns the fields' do
      expect(automation.scriptable.fields).to match_array(
        [
          { extra: {}, name: :cat, component: :text, accepts_placeholders: false, triggerable: nil, required: false },
          { extra: {}, name: :dog, component: :text, accepts_placeholders: true, triggerable: nil, required: false },
          { extra: {}, name: :bird, component: :text, accepts_placeholders: false, triggerable: 'recurring', required: false },
        ]
      )
    end
  end

  describe '#script' do
    it 'returns the script proc' do
      output = capture_stdout do
        automation.scriptable.script.call
      end

      expect(output).to include('script')
    end
  end

  describe '#on_reset' do
    it 'returns the on_reset proc' do
      output = capture_stdout do
        automation.scriptable.on_reset.call
      end

      expect(output).to include('on_reset')
    end
  end

  describe '#placeholders' do
    it 'returns the specified placeholders' do
      expect(automation.scriptable.placeholders).to eq(%i[site_title foo bar])
    end
  end

  describe '#version' do
    it 'returns the specified version' do
      expect(automation.scriptable.version).to eq(1)
    end
  end

  describe '.add' do
    it 'adds the script to the list of available scripts' do
      expect(automation.scriptable).to respond_to(:__scriptable_cats_everywhere)
    end
  end

  describe '.all' do
    it 'returns the list of available scripts' do
      expect(DiscourseAutomation::Scriptable.all).to include(:__scriptable_cats_everywhere)
    end
  end

  describe '.name' do
    it 'returns the name of the script' do
      expect(automation.scriptable.name).to eq('cats_everywhere')
    end
  end

  describe 'triggerable!' do
    fab!(:automation) {
      Fabricate(
        :automation,
        script: 'only_dogs',
        trigger: 'dog'
      )
    }

    it 'has a forced triggerable' do
      expect(automation.scriptable.forced_triggerable).to eq(triggerable: :dog, state: { kind: 'good_boy' })
    end

    it 'returns the forced triggerable in triggerables' do
      expect(automation.scriptable.triggerables).to eq([:dog])
    end
  end

  describe '.utils' do
    describe '.fetch_report' do
      context 'the report doesn’t exist' do
        it 'does nothing' do
          expect(automation.scriptable.utils.fetch_report(:foo)).to eq(nil)
        end
      end

      context 'the report exists' do
        it 'returns the data' do
          freeze_time DateTime.parse("2022-02-25")
          Fabricate(:like, user: Fabricate(:user))
          Fabricate(:like, user: Fabricate(:user))

          expect(automation.scriptable.utils.fetch_report(:likes)).to eq("\n|Day|Count|\n|-|-|\n|2022-02-25|2|\n")
        end
      end
    end

    describe '.apply_placeholders' do
      it 'replaces the given string by placeholders' do
        input = 'hello %%COOL_CAT%%'
        map = { cool_cat: 'siberian cat' }
        output = automation.scriptable.utils.apply_placeholders(input, map)
        expect(output).to eq('hello siberian cat')
      end

      context 'using the REPORT key' do
        context 'no filters specified' do
          it 'replaces REPORT key' do
            freeze_time DateTime.parse("2022-02-22")
            Fabricate(:like, user: Fabricate(:user))
            Fabricate(:like, user: Fabricate(:user))
            input = 'hello %%REPORT=likes%%'

            output = automation.scriptable.utils.apply_placeholders(input, {})
            expect(output).to eq("hello \n|Day|Count|\n|-|-|\n|2022-02-22|2|\n")
          end
        end

        context 'dates specified' do
          it 'replaces REPORT key using dates' do
            freeze_time DateTime.parse("2022-02-14")
            group = Fabricate(:group)
            group.add(Fabricate(:user, created_at: DateTime.parse("2022-02-01")))
            group.add(Fabricate(:user, created_at: DateTime.parse("2022-02-12")))
            input = "hello %%REPORT=signups start_date=2022-02-10%%"

            output = automation.scriptable.utils.apply_placeholders(input, {})
            expect(output).to eq("hello \n|Day|Count|\n|-|-|\n|2022-02-12|1|\n")
          end
        end

        context 'filters specified' do
          it 'replaces REPORT key using filters' do
            freeze_time DateTime.parse("2022-02-15")
            group = Fabricate(:group)
            group.add(Fabricate(:user))
            Fabricate(:user)
            input = "hello %%REPORT=signups group=#{group.id}%%"

            output = automation.scriptable.utils.apply_placeholders(input, {})
            expect(output).to eq("hello \n|Day|Count|\n|-|-|\n|2022-02-15|1|\n")
          end
        end
      end
    end

    describe '.send_pm' do
      let(:user) { Fabricate(:user) }

      context 'pms is delayed' do
        it 'creates a pending pm' do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: 'Tell me and I forget.',
                raw: 'Teach me and I remember. Involve me and I learn.',
                target_usernames: Array(user.username)
              },
              delay: 2,
              automation_id: automation.id
            )
          }.to change { DiscourseAutomation::PendingPm.count }.by(1)
        end
      end

      context 'pms is not delayed' do
        it 'creates a pm' do
          expect {
            DiscourseAutomation::Scriptable::Utils.send_pm(
              {
                title: 'Tell me and I forget.',
                raw: 'Teach me and I remember. Involve me and I learn.',
                target_usernames: Array(user.username)
              }
            )
          }.to change { Post.count }.by(1)
        end
      end
    end
  end
end
