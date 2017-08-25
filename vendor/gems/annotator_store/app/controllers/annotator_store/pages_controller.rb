module AnnotatorStore
  class PagesController < ApplicationController
    before_action :format_input, only: [:search]

    def index
    end

    def search
      @annotations = AnnotatorStore::Annotation.where(search_params)
      @total = @annotations.size
    end

    private

    def format_input
      params[:search] = {}
      params[:search][:uri] = params[:uri]
    end

    def search_params
      params.require(:search).permit(:uri)
    end
  end
end
