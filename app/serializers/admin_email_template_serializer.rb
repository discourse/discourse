# frozen_string_literal: true

class AdminEmailTemplateSerializer < ApplicationSerializer
  attributes :id, :title, :subject, :body, :can_revert?, :interpolation_keys

  def id
    object
  end

  def title
    if I18n.exists?("#{object}.title")
      I18n.t("#{object}.title")
    else
      object.gsub(/.*\./, "").titleize
    end
  end

  def subject
    if I18n.exists?("#{object}.subject_template.other")
      @subject = nil
    else
      @subject ||= I18n.t("#{object}.subject_template")
    end
  end

  def body
    @body ||= I18n.t("#{object}.text_body_template")
  end

  def can_revert?
    subject_key = "#{object}.subject_template"
    body_key = "#{object}.text_body_template"
    keys = [subject_key, body_key]
    if options[:overridden_keys]
      keys.any? { |k| options[:overridden_keys].include?(k) }
    else
      TranslationOverride.exists?(locale: I18n.locale, translation_key: keys)
    end
  end

  def interpolation_keys
    @interpolation_keys ||=
      begin
        keys = []

        subject_key = "#{object}.subject_template"
        subject_text = I18n.overrides_disabled { I18n.t(subject_key, locale: :en, default: "") }
        keys |= I18nInterpolationKeysFinder.find(subject_text) if subject_text.is_a?(String)

        body_key = "#{object}.text_body_template"
        body_text = I18n.overrides_disabled { I18n.t(body_key, locale: :en, default: "") }
        keys |= I18nInterpolationKeysFinder.find(body_text) if body_text.is_a?(String)

        keys |= TranslationOverride.custom_interpolation_keys(object)

        keys.sort
      end
  end
end
