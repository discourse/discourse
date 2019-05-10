# frozen_string_literal: true

require 'rails_helper'

describe TopicInvite do

  it { is_expected.to belong_to :topic }
  it { is_expected.to belong_to :invite }
  it { is_expected.to validate_presence_of :topic_id }
  it { is_expected.to validate_presence_of :invite_id }

end
