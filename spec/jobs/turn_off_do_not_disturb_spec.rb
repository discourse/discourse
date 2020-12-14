# frozen_string_literal: true

require "rails_helper"

describe Jobs::UnsilenceUsers do
  it "published a message to the client when do not disturb has ended" do
    freeze_time
    user = Fabricate(:user)
    timing = Fabricate(:do_not_disturb_timing, user: user, starts_at: Time.current - 1.day, ends_at: Time.current - 30.seconds)
    MessageBus.expects(:publish).with("/do-not-disturb/#{user.id}", { ends_at: nil }, user_ids: [user.id])
    Jobs::TurnOffDoNotDisturb.new.execute({})
  end
end
