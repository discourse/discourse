# frozen_string_literal: true

class EmbeddableHostTag < ActiveRecord::Base
  belongs_to :embeddable_host
  belongs_to :tag

  validates :embeddable_host_id, presence: true
  validates :tag_id, presence: true
  validates :embeddable_host_id, uniqueness: { scope: :tag_id }
end
