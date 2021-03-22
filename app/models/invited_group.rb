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
#  group_id   :integer
#  invite_id  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_invited_groups_on_group_id_and_invite_id  (group_id,invite_id) UNIQUE
#
