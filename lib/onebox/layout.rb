# frozen_string_literal: true

require_relative "template_support"

module Onebox
  class Layout < Mustache
    include TemplateSupport

    VERSION = "1.0.0"

    attr_reader :record
    attr_reader :view

    def initialize(name, record)
      @record = Onebox::Helpers.symbolize_keys(record)

      # Fix any relative paths
      if @record[:image] && @record[:image] =~ %r{\A/[^/]}
        @record[:image] = "#{uri.scheme}://#{uri.host}/#{@record[:image]}"
      end

      @md5 = Digest::MD5.new
      @view = View.new(name, @record)
      @template_name = "_layout"
      @template_path = load_paths.last
    end

    def to_html
      render(details)
    end

    private

    def uri
      @uri ||= URI(::Onebox::Helpers.normalize_url_for_output(record[:link]))
    end

    def details
      {
        link: record[:link],
        title: record[:title],
        favicon: record[:favicon],
        domain: record[:domain] || uri.host.to_s.sub(/\Awww\./, ""),
        article_published_time: record[:article_published_time],
        article_published_time_title: record[:article_published_time_title],
        metadata_1_label: record[:metadata_1_label],
        metadata_1_value: record[:metadata_1_value],
        metadata_2_label: record[:metadata_2_label],
        metadata_2_value: record[:metadata_2_value],
        subname: view.template_name,
        view: view.to_html,
      }
    end
  end
end
