class TosController < ApplicationController

  skip_before_filter :check_xhr

  def index
    @company_shortname = 'CDCK'
    @company_fullname = 'Civilized Discourse Construction Kit, Inc.'
    @company_domain = 'discourse.org'
    render
  end

end