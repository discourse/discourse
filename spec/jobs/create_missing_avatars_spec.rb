# frozen_string_literal: true

require 'rails_helper'

describe Jobs::CreateMissingAvatars do
  it "runs correctly without crashing" do
    Jobs::CreateMissingAvatars.new.execute(nil)
  end
end
