# frozen_string_literal: true

require "reverse_markdown"
require "markdown_endpoint/accept_header"
require "markdown_endpoint/request_constraint"
require "markdown_endpoint/vary_middleware"
require "markdown_endpoint/cooked_processor"
require "markdown_endpoint/topic_renderer"
require "markdown_endpoint/topic_list_renderer"
require "markdown_endpoint/controller_support"

Mime::Type.register("text/markdown", :md) unless Mime::Type.lookup_by_extension(:md)
Rails.application.config.middleware.insert_before(0, MarkdownEndpoint::VaryMiddleware)

Rails.application.config.to_prepare do
  ApplicationController.include(MarkdownEndpoint::ControllerSupport)
end
