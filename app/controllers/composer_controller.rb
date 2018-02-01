require_dependency 'html_to_markdown'

class ComposerController < ApplicationController

  prepend_before_action :check_xhr, :ensure_logged_in

  def parse_html
    markdown_text = HtmlToMarkdown.new(params[:html]).to_markdown

    render json: { markdown: markdown_text }
  end
end
