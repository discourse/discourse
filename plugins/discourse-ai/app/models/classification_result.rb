# frozen_string_literal: true

class ClassificationResult < ActiveRecord::Base
  belongs_to :target, polymorphic: true

  def self.has_sentiment_classification?
    where(classification_type: "sentiment").exists?
  end
end

# == Schema Information
#
# Table name: classification_results
#
#  id                  :bigint           not null, primary key
#  model_used          :string
#  classification_type :string
#  target_id           :bigint
#  target_type         :string
#  classification      :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  unique_classification_target_per_type  (target_id,target_type,model_used) UNIQUE
#
