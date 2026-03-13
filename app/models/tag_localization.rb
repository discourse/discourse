# frozen_string_literal: true

class TagLocalization < ActiveRecord::Base
  include LocaleMatchable

  belongs_to :tag

  before_validation :clean_name

  validates :locale, presence: true, length: { maximum: 20 }
  validates :name, presence: true
  validates :tag_id, uniqueness: { scope: :locale }
  validates :description, length: { maximum: 1000 }

  private

  def clean_name
    self.name = DiscourseTagging.clean_tag(name) if name.present?
  end
end

# == Schema Information
#
# Table name: tag_localizations
#
#  id          :bigint           not null, primary key
#  tag_id      :bigint           not null
#  locale      :string(20)       not null
#  name        :string           not null
#  description :string(1000)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_tag_localizations_on_tag_id             (tag_id)
#  index_tag_localizations_on_tag_id_and_locale  (tag_id,locale) UNIQUE
#
