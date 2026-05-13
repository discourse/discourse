# frozen_string_literal: true

class InvitedGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :invite
end

# == Schema Information
#
# Table name: invited_groups
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  group_id   :integer
#  invite_id  :integer
#
# Indexes
#
#  index_invited_groups_on_group_id_and_invite_id  (group_id,invite_id) UNIQUE
#
