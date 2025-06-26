# frozen_string_literal: true

class InviteCustomField < ActiveRecord::Base
  include CustomField

  belongs_to :invite
end

# == Schema Information
#
# Table name: invite_custom_fields
#
#  id          :integer          not null, primary key
#  invite_id   :integer          not null
#  name        :string(256)      not null
#  value       :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_invite_custom_fields_on_invite_id_and_name  (invite_id,name)
#
