# frozen_string_literal: true

module JsonApiKit
  class BaseController < ::ApplicationController
    MissingDeclaration = Class.new(StandardError)

    ROOT = "/api"
    OTHER_PARAMETER = "Content-Type accepts the ext and profile parameters only."
    NO_EXTENSION = "This API applies no extension."
    UNREADABLE_ACCEPT =
      "Accept must allow #{MediaType::JSON_API} with the ext and profile parameters only."

    skip_before_action :check_xhr,
                       :redirect_to_login_if_required,
                       :verify_authenticity_token,
                       raise: false

    class_attribute :declared_resource, instance_accessor: false

    before_action :set_json_format
    before_action :set_vary_header
    before_action :negotiate

    rescue_from(Discourse::InvalidAccess) { render_document(Document::Errors.new(Forbidden.new)) }

    class << self
      def resource(declaration)
        self.declared_resource = ResourceLookup.resource(declaration, within: self)
      end
    end

    def rescue_with_handler(*)
      super || render_server_error(*)
    end

    def index
      render_document(
        Document::Collection.for(request.query_parameters, resource:, guardian:, urls:),
      )
    end

    def show
      render_document(
        Document::Individual.for(
          params[:id],
          request.query_parameters,
          resource:,
          guardian:,
          urls:,
        ),
      )
    end

    private

    def resource
      self.class.declared_resource or
        raise MissingDeclaration,
              "#{self.class}: declare the resource it serves with `resource :things`"
    end

    def urls
      Urls.new(
        base: "#{request.base_url}#{ROOT}",
        current: "#{request.base_url}#{request.path}",
        parameters: request.query_parameters,
      )
    end

    def set_json_format = request.format = :json

    def set_vary_header = response.headers["Vary"] ||= "Accept"

    def render_server_error(error)
      Discourse.warn_exception(error, message: "JSON:API request failed")
      render_document(Document::Errors.new(InternalServerError.new))
    end

    def render_document(document)
      render json: document.to_h,
             status: document.status,
             content_type: Pagination::Profile::MEDIA_TYPE
    end

    def negotiate
      (content_type_refusal || accept_refusal).try { render_document(Document::Errors.new(it)) }
    end

    def content_type_refusal
      return unless request_media_type&.json_api?
      return UnsupportedMediaType.new(OTHER_PARAMETER) if request_media_type.modified?
      UnsupportedMediaType.new(NO_EXTENSION) if request_media_type.extended?
    end

    def accept_refusal
      return if accepted_media_types.empty? || accepted_media_types.any? { !it.modified? }
      NotAcceptable.new(UNREADABLE_ACCEPT)
    end

    def request_media_type
      @request_media_type ||= MediaType.parse(request.headers["Content-Type"]).first
    end

    def accepted_media_types
      @accepted_media_types ||= MediaType.parse(request.headers["Accept"]).select(&:json_api?)
    end
  end
end
