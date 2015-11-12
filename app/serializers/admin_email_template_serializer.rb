class AdminEmailTemplateSerializer < ApplicationSerializer
  attributes :id, :title, :subject, :body

  def id
    object
  end

  def title
    object.gsub(/.*\./, '').titleize
  end

  def subject
    I18n.t("#{object}.subject_template")
  end

  def body
    I18n.t("#{object}.text_body_template")
  end
end
