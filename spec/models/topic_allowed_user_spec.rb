# frozen_string_literal: true

require 'rails_helper'

describe TopicAllowedUser do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :topic }
end
