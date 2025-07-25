# frozen_string_literal: true

describe DiscourseTemplates::UsageCount do
  it { is_expected.to belong_to :topic }
  it { is_expected.to validate_presence_of :topic_id }
end
