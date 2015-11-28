class AdminEmailTemplateSerializer < ApplicationSerializer
  attributes :id, :title, :subject, :body, :can_revert?

  def id
    object
  end

  def title
    object.gsub(/.*\./, '').titleize
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
    current_body, current_subject = body, subject

    I18n.overrides_disabled do
      return I18n.t("#{object}.subject_template") != current_subject ||
             I18n.t("#{object}.text_body_template") != current_body
    end
  end
end
