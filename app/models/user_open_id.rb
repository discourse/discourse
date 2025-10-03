# frozen_string_literal: true

# This table is no longer used in core, but may be used by unofficial plugins
class UserOpenId < ActiveRecord::Base
  after_initialize :raise_deprecation_error

  belongs_to :user

  validates_presence_of :email
  validates_presence_of :url

  private

  def raise_deprecation_error
    raise "The user_open_ids table has been deprecated, and will be dropped in v2.5. See https://meta.discourse.org/t/-/113249"
  end
end

# == Schema Information
#
# Table name: user_open_ids
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  email      :string           not null
#  url        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  active     :boolean          not null
#
# Indexes
#
#  index_user_open_ids_on_url  (url)
#
