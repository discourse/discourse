require_dependency 'highlighter'

class HighlightController < ApplicationController
  skip_before_filter :check_xhr, :verify_authenticity_token

  def show

    respond_to do |format|
      format.any {
        render js: generate_highlight(), content_type: 'text/javascript'
      }
    end

  end

  def generate_highlight()
    Highlighter.generate SiteSetting.enabled_languages.split('|'), "public/javascripts/highlight.pack.js"
  end
end
