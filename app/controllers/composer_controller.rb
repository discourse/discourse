# frozen_string_literal: true

class ComposerController < ApplicationController

  requires_login

  def parse_html
    markdown_text = HtmlToMarkdown.new(params[:html]).to_markdown

    render json: { markdown: markdown_text }
  end
end
