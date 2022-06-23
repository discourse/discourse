# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'AppendLastEditedBy' do
  fab!(:post) { Fabricate(:post, raw: 'this is a post with no edit') }
  fab!(:moderator) { Fabricate(:moderator) }

  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scriptable::APPEND_LAST_EDITED_BY
    )
  end

  def trigger_automation(post)
    cooked = automation.trigger!('post' => post, 'cooked' => post.cooked)
    updated_at = post.updated_at
    date_time = updated_at.strftime("%Y-%m-%dT%H:%M:%SZ")
    [cooked, updated_at, date_time]
  end

  context "#trigger!" do
    it 'works for newly created post' do
      cooked, updated_at, date_time = trigger_automation(post)
      expect(cooked.ends_with?("<blockquote>\n<p>Last edited by #{post.username} <span data-date=\"#{updated_at.to_date.to_s}\" data-time=\"#{updated_at.strftime("%H:%M:%S")}\" class=\"discourse-local-date\" data-timezone=\"UTC\" data-email-preview=\"#{date_time} UTC\">#{date_time}</span></p>\n</blockquote>\n</div>")).to be_truthy
    end

    it 'works for existing post with last edited by detail' do
      cooked, updated_at, date_time = trigger_automation(post)
      expect(cooked.include?("<p>Last edited by #{post.username} <span data-date=\"#{updated_at.to_date.to_s}\" data-time=\"#{updated_at.strftime("%H:%M:%S")}\" class=\"discourse-local-date\" data-timezone=\"UTC\" data-email-preview=\"#{date_time} UTC\">#{date_time}</span></p>")).to be_truthy

      PostRevisor.new(post).revise!(moderator, raw: 'this is a post with edit')

      cooked, updated_at, date_time = trigger_automation(post.reload)
      expect(cooked.include?("<p>Last edited by #{moderator.username} <span data-date=\"#{updated_at.to_date.to_s}\" data-time=\"#{updated_at.strftime("%H:%M:%S")}\" class=\"discourse-local-date\" data-timezone=\"UTC\" data-email-preview=\"#{date_time} UTC\">#{date_time}</span></p>")).to be_truthy
    end
  end
end
