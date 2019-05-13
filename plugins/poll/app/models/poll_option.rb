# frozen_string_literal: true

class PollOption < ActiveRecord::Base
  belongs_to :poll
  has_many :poll_votes, dependent: :delete_all
end

# == Schema Information
#
# Table name: poll_options
#
#  id              :bigint           not null, primary key
#  poll_id         :bigint
#  digest          :string           not null
#  html            :text             not null
#  anonymous_votes :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_poll_options_on_poll_id             (poll_id)
#  index_poll_options_on_poll_id_and_digest  (poll_id,digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (poll_id => polls.id)
#
