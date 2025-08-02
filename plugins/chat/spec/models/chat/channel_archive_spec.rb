# frozen_string_literal: true

RSpec.describe Chat::ChannelArchive do
  it { is_expected.to validate_length_of(:archive_error).is_at_most(1000) }
  it { is_expected.to validate_length_of(:destination_topic_title).is_at_most(1000) }
end
