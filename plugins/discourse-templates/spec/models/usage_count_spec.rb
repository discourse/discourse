# frozen_string_literal: true

require "rails_helper"

describe DiscourseTemplates::UsageCount do
  it { is_expected.to belong_to :topic }
  it { is_expected.to validate_presence_of :topic_id }
end
