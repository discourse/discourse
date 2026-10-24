# frozen_string_literal: true

class PostFormDataValidator < ActiveModel::Validator
  def validate(post)
    return if post.form_data.nil?
    unless post.new_record? || post.will_save_change_to_form_data? ||
             post.will_save_change_to_raw? || post.will_save_change_to_post_number?
      return
    end

    unless post.is_first_post?
      post.errors.add(:form_data, :invalid)
      return
    end

    rendered = TextCleaner.normalize_whitespaces(post.form_submission.render).rstrip
    post.errors.add(:raw, :invalid) if post.raw != rendered
  rescue ArgumentError, FormTemplate::InvalidAnswers, Liquid::Error
    post.errors.add(:form_data, :invalid)
  end
end
