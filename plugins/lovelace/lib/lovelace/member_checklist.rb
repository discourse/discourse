# frozen_string_literal: true

module ::Lovelace
  class MemberChecklist
    def self.for_user(user)
      items = Checklist.read["items"]
      state = PluginStore.get(PLUGIN_NAME, "member_checklist_#{user.id}") || {}
      {
        items: items,
        completed_ids: (state["completed_ids"] || []) & items.map { |item| item["id"] },
        minimized: state["minimized"] == true,
        dismissed: state["dismissed"] == true,
      }
    end

    def self.update!(user, params)
      DistributedMutex.synchronize("lovelace_member_checklist_#{user.id}") do
        state = for_user(user)
        if params.key?(:seen) && ![true, false].include?(params[:seen])
          raise Discourse::InvalidParameters.new(:seen)
        end
        if params.key?(:clicked_item_id) &&
             state[:items].none? { |item| item["id"] == params[:clicked_item_id] }
          raise Discourse::InvalidParameters.new(:clicked_item_id)
        end
        visible = state[:items].present? && !state[:dismissed]
        if params.key?(:item_id)
          id = params[:item_id]
          unless state[:items].any? { |item| item["id"] == id } &&
                   [true, false].include?(params[:completed])
            raise Discourse::InvalidParameters.new(:item_id)
          end
          state[:completed_ids] -= [id]
          state[:completed_ids] << id if params[:completed]
        end
        %i[minimized dismissed].each do |field|
          next unless params.key?(field)
          raise Discourse::InvalidParameters.new(field) if [true, false].exclude?(params[field])
          state[field] = params[field]
        end
        stored = PluginStore.get(PLUGIN_NAME, "member_checklist_#{user.id}") || {}
        reporting = stored["reporting"] || {}
        reporting["seen_at"] ||= Time.current.iso8601 if params[:seen] == true && visible
        if reporting["seen_at"]
          if params.key?(:clicked_item_id)
            reporting["clicked_items"] ||= {}
            reporting["clicked_items"][params[:clicked_item_id]] ||= Time.current.iso8601
            reporting["clicked"] = true
            if state[:items].all? { |item| reporting["clicked_items"].key?(item["id"]) }
              reporting["clicked_all"] = true
            end
          end
          reporting["completed_items"] ||= {}
          state[:completed_ids].each do |completed_id|
            reporting["completed_items"][completed_id] ||= Time.current.iso8601
          end
          reporting["engaged"] = true if reporting["completed_items"].present?
          if state[:items].present? && state[:completed_ids].size == state[:items].size
            reporting["completed"] = true
          end
          if state[:dismissed]
            reporting["dismissed"] = true
            reporting["dismissed_without_completion"] = true unless reporting["engaged"]
          end
        end
        PluginStore.set(
          PLUGIN_NAME,
          "member_checklist_#{user.id}",
          state.except(:items).merge(reporting: reporting),
        )
        state
      end
    end
  end
end
