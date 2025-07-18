# frozen_string_literal: true

require "rails_helper"

describe Topic do
  before do
    freeze_time
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:user) { Fabricate(:user, refresh_auto_groups: true) }

  context "when a topic is created" do
    context "with a date in title" do
      it "doesn’t create a post event" do
        post_with_date =
          PostCreator.create!(
            user,
            title: "Let’s buy a boat with me tomorrow",
            raw: "The boat market is quite active lately.",
          )

        expect(DiscoursePostEvent::Event).to_not exist(id: post_with_date.id)
      end
    end
  end
end
