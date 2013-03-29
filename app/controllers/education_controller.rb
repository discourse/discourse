class EducationController < ApplicationController

  before_filter :ensure_logged_in

  def show
    raise Discourse::InvalidAccess.new unless params[:id] =~ /^[a-z0-9\-\_]+$/
    raise Discourse::NotFound.new if I18n.t("education.#{params[:id]}", default: MISSING_KEY) == MISSING_KEY

    education_posts_text = I18n.t('education.until_posts', count: SiteSetting.educate_until_posts)

    markdown_content = MultisiteI18n.t("education.#{params[:id]}",
                                       site_name: SiteSetting.title,
                                       education_posts_text: education_posts_text)
    render text: PrettyText.cook(markdown_content)
  end

  private
  MISSING_KEY = '_MISSING_KEY_'.freeze

end
