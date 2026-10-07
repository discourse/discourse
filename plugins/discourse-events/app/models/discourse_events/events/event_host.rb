# frozen_string_literal: true

module DiscourseEvents
  module Events
    class EventHost < ActiveRecord::Base
      self.table_name = "discourse_post_event_hosts"

      belongs_to :event, foreign_key: :post_id
      belongs_to :user
    end
  end
end

# == Schema Information
#
# Table name: discourse_post_event_hosts
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :bigint           not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_discourse_post_event_hosts_on_post_id_and_user_id  (post_id,user_id) UNIQUE
#  index_discourse_post_event_hosts_on_user_id              (user_id)
#
