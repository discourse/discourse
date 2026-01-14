# frozen_string_literal: true

class ModelAccuracy < ActiveRecord::Base
  def self.adjust_model_accuracy(new_status, reviewable)
    return if %i[approved rejected].exclude?(new_status)
    return if [ReviewableAiPost, ReviewableAiChatMessage].exclude?(reviewable.class)

    verdicts = reviewable.payload.to_h["verdicts"] || {}

    verdicts.each do |model_name, verdict|
      accuracy_model = find_by(model: model_name)

      attribute =
        if verdict
          new_status == :approved ? :flags_agreed : :flags_disagreed
        else
          new_status == :rejected ? :flags_agreed : :flags_disagreed
        end

      accuracy_model.increment!(attribute)
    end
  end

  def calculate_accuracy
    return 0 if total_flags.zero?

    (flags_agreed * 100) / total_flags
  end

  private

  def total_flags
    flags_agreed + flags_disagreed
  end
end

# == Schema Information
#
# Table name: model_accuracies
#
#  id                  :bigint           not null, primary key
#  model               :string           not null
#  classification_type :string           not null
#  flags_agreed        :integer          default(0), not null
#  flags_disagreed     :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_model_accuracies_on_model  (model) UNIQUE
#
