# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'GiftExchange' do
  fab!(:automation) { Fabricate(:automation, script: DiscourseAutomation::Scriptable::GIFT_EXCHANGE, trigger: DiscourseAutomation::Triggerable::POINT_IN_TIME) }
  fab!(:gift_group) { Fabricate(:group) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user) }

  before do
    SiteSetting.discourse_automation_enabled = true

    gift_group.add(user_1)
    gift_group.add(user_2)
    gift_group.add(user_3)

    automation.upsert_field!('gift_exchangers_group', 'group', { value: gift_group.id }, target: 'script')
    automation.upsert_field!('giftee_assignment_messages', 'pms', { value: [{ title: 'Gift %%YEAR%%', raw: '@%%GIFTER_USERNAME%% you should send a gift to %%GIFTEE_USERNAME%%'}] }, target: 'script')
  end

  context 'ran from point_in_time trigger' do
    before do
      automation.upsert_field!('execute_at', 'date_time', { value: 3.hours.from_now }, target: 'trigger')
    end

    it 'creates expected PM' do
      freeze_time 6.hours.from_now do
        expect {
          Jobs::DiscourseAutomationTracker.new.execute

          raws = Post.order(created_at: :desc).limit(3).pluck(:raw)
          expect(raws.any? { |r| r.start_with?("@#{user_1.username}") }).to be_truthy
          expect(raws.any? { |r| r.start_with?("@#{user_2.username}") }).to be_truthy
          expect(raws.any? { |r| r.start_with?("@#{user_3.username}") }).to be_truthy
          expect(raws.any? { |r| r.end_with?("#{user_1.username}") }).to be_truthy
          expect(raws.any? { |r| r.end_with?("#{user_2.username}") }).to be_truthy
          expect(raws.any? { |r| r.end_with?("#{user_3.username}") }).to be_truthy

          title = Post.order(created_at: :desc).limit(3).map { |post| post.topic.title }.uniq.first
          expect(title).to eq("Gift #{Time.zone.now.year}")
        }.to change { Post.count }.by(3) # each pair receives a PM
      end
    end
  end
end
