# frozen_string_literal: true

class Admin::Config::CategoryManagementController < Admin::AdminController
  def categories
    per_page =
      if params[:per_page].present?
        params[:per_page].to_i.clamp(1, ListAdminCategories::MAX_PER_PAGE)
      else
        ListAdminCategories::DEFAULT_PER_PAGE
      end
    page = fetch_page_from_params(max: per_page)

    ListAdminCategories.call(
      **service_params.deep_merge(params: { per_page: per_page, page: page }),
    ) do
      on_success do |category_page:|
        render_json_dump(
          categories:
            ActiveModel::ArraySerializer.new(
              category_page[:categories],
              each_serializer: AdminCategorySerializer,
              scope: guardian,
            ).as_json,
          has_more: category_page[:has_more],
        )
      end

      on_failed_policy(:category_type_exists) { raise Discourse::NotFound }
    end
  end
end
