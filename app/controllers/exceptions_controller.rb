class ExceptionsController < ApplicationController
  skip_before_filter :check_xhr
  layout 'no_js'

  def not_found
    f = Topic.where(deleted_at: nil, archetype: "regular")

    @latest = f.order('views desc').take(10)
    @recent = f.order('created_at desc').take(10)
    @slug =  params[:slug].class == String ? params[:slug] : ''
    @slug.gsub!('-',' ')
    render status: 404
  end
end
