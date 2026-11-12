# frozen_string_literal: true

module DiscourseWorkflows
  class ContextHelpers
    include NodeErrorHandling

    def initialize(node_identifier:, data_table_access_validator: nil, guardian: nil)
      @data_table_proxy_provider =
        DataTables::NodeProxyProvider.new(
          node_identifier: node_identifier,
          data_table_access_validator: data_table_access_validator,
          guardian: guardian,
        )
    end

    def get_data_table_proxy(data_table_id)
      @data_table_proxy_provider.get_data_table_proxy(data_table_id)
    end

    def get_data_table_aggregate_proxy
      @data_table_proxy_provider.get_data_table_aggregate_proxy
    end

    def normalize_items(items)
      Item.normalize_items(items)
    rescue Item::InconsistentItemFormatError
      raise_node_error!(
        I18n.t("discourse_workflows.errors.item.inconsistent_format_title"),
        description: I18n.t("discourse_workflows.errors.item.inconsistent_format"),
      )
    end
  end
end
