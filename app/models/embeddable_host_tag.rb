# frozen_string_literal: true

class EmbeddableHostTag < ActiveRecord::Base
  belongs_to :embeddable_host
  belongs_to :tag

  validates :embeddable_host_id, presence: true
  validates :tag_id, presence: true
  validates :embeddable_host_id, uniqueness: { scope: :tag_id }
end

# == Schema Information
#
# Table name: embeddable_host_tags
#
#  id                 :bigint           not null, primary key
#  embeddable_host_id :integer          not null
#  tag_id             :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_embeddable_host_tags_on_embeddable_host_id             (embeddable_host_id)
#  index_embeddable_host_tags_on_embeddable_host_id_and_tag_id  (embeddable_host_id,tag_id) UNIQUE
#  index_embeddable_host_tags_on_tag_id                         (tag_id)
#
