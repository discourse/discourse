# frozen_string_literal: true

class Admin::SearchController < Admin::AdminController
  RESULT_TYPES = %w[page setting theme component report].freeze

  def index
    respond_to do |format|
      format.json do
        Admin::Search::List.call(service_params) do |result|
          on_success do |settings:, themes_and_components:, reports:, upcoming_changes:|
            themes_and_components_json =
              ActiveModel::ArraySerializer.new(
                themes_and_components,
                each_serializer: BasicThemeSerializer,
                scope: guardian,
              ).as_json

            render_json_dump(
              settings:,
              themes_and_components: themes_and_components_json,
              reports:,
              upcoming_changes:,
            )
          end
          on_failed_contract do |contract|
            render(
              json: failed_json.merge(errors: contract.errors.full_messages),
              status: :bad_request,
            )
          end
          on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
        end
      end

      format.html { render body: nil }
    end
  end
end
