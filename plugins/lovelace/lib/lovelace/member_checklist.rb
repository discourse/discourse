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
        PluginStore.set(PLUGIN_NAME, "member_checklist_#{user.id}", state.except(:items))
        state
      end
    end
  end
end
