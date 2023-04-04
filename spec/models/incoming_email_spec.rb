# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncomingEmail do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:topic) }
  it { is_expected.to belong_to(:post) }
  it { is_expected.to belong_to(:group).with_foreign_key(:imap_group_id).class_name("Group") }
  it { is_expected.to validate_length_of(:raw).is_at_most(100.megabytes) }
  it { is_expected.to validate_presence_of(:created_via) }
end
