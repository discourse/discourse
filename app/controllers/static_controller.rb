class StaticController < ApplicationController

  skip_before_filter :check_xhr

  def show

    page = params[:id]

    # Don't allow paths like ".." or "/" or anything hacky like that
    page.gsub!(/[^a-z0-9\_\-]/, '')

    # Some variables to substitute
    @company_shortname = 'CDCK'
    @company_fullname = 'Civilized Discourse Construction Kit, Inc.'
    @company_domain = 'discourse.org'

    file = "static/#{page}.html"
    templates = lookup_context.find_all(file)
    if templates.any?
      render "static/#{page}", layout: !request.xhr?, formats: [:html]
      return
    end

    render file: 'public/404', layout: false, status: 404
  end

end
