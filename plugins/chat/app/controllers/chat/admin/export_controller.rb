# frozen_string_literal: true

module Chat
  module Admin
    class ExportController < ::Admin::AdminController
      requires_plugin Chat::PLUGIN_NAME

      def export_messages
        entity = "chat_message"
        Jobs.enqueue(:export_csv_file, entity: entity, user_id: current_user.id)
        StaffActionLogger.new(current_user).log_entity_export(entity)
      end
    end
  end
end
