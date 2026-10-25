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

    rendered = post.form_submission.normalized_raw
    post.errors.add(:base, I18n.t("form_templates.raw_managed_by_form")) if post.raw != rendered
  rescue ArgumentError, FormTemplate::InvalidAnswers, Liquid::Error
    post.errors.add(:form_data, :invalid)
  end
end
