# frozen_string_literal: true

module ::Blog
  # Page loads of these paths render the admin app, through check_xhr.
  class BlogsController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME
    before_action :ensure_discussion_host

    def index
      blogs = Instance.ordered.to_a
      render json: {
               blogs: serialize_data(blogs, InstanceSerializer, article_counts:),
               can_add_blog: Instance.addable?,
             }
    end

    def show
      blog = Instance.find_by(id: params[:id]) || raise(Discourse::NotFound)
      render json: serialize_blog(blog)
    end

    def create
      Instance::Create.call(service_params.deep_merge(params: blog_params)) do
        on_success { |blog:| render json: serialize_blog(blog), status: :created }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_failed_policy(:can_manage_blogs) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_add_blog) do
          render_json_error I18n.t("blog.errors.blog_limit", count: SiteSetting.blog_max_instances),
                            status: :unprocessable_entity
        end
        on_model_errors(:blog) do |blog|
          render_json_error blog,
                            status: :unprocessable_entity,
                            extras: {
                              field_errors: blog.errors.to_hash,
                            }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def update
      Instance::Update.call(
        service_params.deep_merge(params: blog_params.merge(blog_id: params[:id])),
      ) do
        on_success { |blog:| render json: serialize_blog(blog) }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_failed_policy(:can_manage_blogs) { raise Discourse::InvalidAccess }
        on_model_not_found(:blog) { raise Discourse::NotFound }
        on_model_errors(:blog) { |blog| render_json_error blog, status: :unprocessable_entity }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def destroy
      Instance::Destroy.call(service_params.deep_merge(params: { blog_id: params[:id] })) do
        on_success { head :no_content }
        on_failed_policy(:can_manage_blogs) { raise Discourse::InvalidAccess }
        on_model_not_found(:blog) { raise Discourse::NotFound }
        on_failed_policy(:not_default) do
          render_json_error I18n.t("blog.errors.default_blog_undeletable"),
                            status: :unprocessable_entity
        end
        on_failed_policy(:no_articles) do
          render_json_error I18n.t("blog.errors.blog_has_articles"), status: :unprocessable_entity
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def blog_params
      params
        .require(:blog)
        .permit(*Instance::AttributesContract::FIELDS, :published)
        .to_h
        .symbolize_keys
    end

    def article_counts
      @article_counts ||= Publication.group(:blog_id).count
    end

    def serialize_blog(blog)
      InstanceSerializer.new(blog, scope: guardian, root: false, article_counts:).as_json
    end

    def ensure_discussion_host
      raise Discourse::NotFound if Configuration.blog_host?(request)
    end
  end
end
