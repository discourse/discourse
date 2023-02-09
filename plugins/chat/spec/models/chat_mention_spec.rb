# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChatMessage do
  it { is_expected.to have_many(:chat_mentions).dependent(:destroy) }
end
