require_dependency 'annotator_store/application_controller'

module AnnotatorStore
  class AnnotationsController < ApplicationController
    before_action :set_annotation, only: [:show, :update, :destroy]

    # POST /annotations
    def create
      format_client_input_to_rails_convention_for_create
      @annotation = Annotation.new(annotation_params)
      @annotation.creator = current_user
      respond_to do |format|
        if @annotation.save
          format.json { render :show, status: :created, location: annotation_url(@annotation) }
        else
          format.json { render json: @annotation.errors, status: :unprocessable_entity }
        end
      end
    end

    # GET /annotations/1
    def show
    end

    # PATCH/PUT /annotations/1
    def update
      format_client_input_to_rails_convention_for_update
      respond_to do |format|
        if @annotation.update(annotation_params)
          format.json { render :show, status: :ok, location: annotation_url(@annotation) }
        else
          format.json { render json: @annotation.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /annotations/1
    def destroy
      @annotation.destroy
      respond_to do |format|
        format.json { head :no_content, status: :no_content }
      end
    end

    # OPTIONS /annotations
    def options
      respond_to do |format|
        format.json { render :options }
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_annotation
      @annotation = Annotation.find(params[:id])
    end

    # Convert the data sent by AnnotatorJS to the format that Rails expects so
    # that we are able to create a proper params object
    def format_client_input_to_rails_convention_for_create
      params[:annotation] = {}
      params[:annotation][:version] = params[:annotator_schema_version] unless params[:annotator_schema_version].blank?
      params[:annotation][:text] = params[:text] unless params[:text].blank?
      params[:annotation][:quote] = params[:quote] unless params[:quote].blank?
      params[:annotation][:uri] = params[:uri] unless params[:uri].blank?
      params[:annotation][:post_id] = params[:post] unless params[:post].blank?
      params[:annotation][:tag_id] = get_tag_id unless params[:tags].blank?
      params[:annotation][:ranges_attributes] = params[:ranges].map do |r|
        range = {}
        range[:start]        = r[:start]
        range[:end]          = r[:end]
        range[:start_offset] = r[:startOffset]
        range[:end_offset]   = r[:endOffset]
        range
      end unless params[:ranges].blank?
    end

    # Convert the data sent by AnnotatorJS to the format that Rails expects so
    # that we are able to create a proper params object
    def format_client_input_to_rails_convention_for_update
      params[:annotation] = {}
      params[:annotation][:version] = params[:annotator_schema_version] unless params[:annotator_schema_version].blank?
      params[:annotation][:text] = params[:text] unless params[:text].blank?
      params[:annotation][:quote] = params[:quote] unless params[:quote].blank?
      params[:annotation][:tag_id] = params[:tags].present? ? get_tag_id : nil
      params[:annotation][:uri] = params[:uri] unless params[:uri].blank?
    end

    # Only allow a trusted parameter 'white list' through.
    def annotation_params
      params.require(:annotation).permit(
       :text,
       :quote,
       :uri,
       :version,
       :tag_id,
       :post_id,
       ranges_attributes: [:start, :end, :start_offset, :end_offset]
      )
    end

    def get_tag_id
      Tag.find_by(name: params[:tags].join(' ').split(' → ').last.strip).try(:id)
    end

  end
end
