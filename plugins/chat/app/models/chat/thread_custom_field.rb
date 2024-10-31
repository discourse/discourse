# frozen_string_literal: true

module Chat
  class ThreadCustomField < ActiveRecord::Base
    belongs_to :thread
  end
end

# == Schema Information
#
# Table name: chat_thread_custom_fields
#
#  id         :bigint           not null, primary key
#  thread_id  :bigint           not null
#  name       :string(256)      not null
#  value      :string(1000000)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_chat_thread_custom_fields_on_thread_id  (thread_id)
#
