# frozen_string_literal: true

# Helps us respond with a topic list from a controller
module TopicListResponder
  def respond_with_list(list)
    discourse_expires_in 1.minute

    if guardian.anonymous? && SiteSetting.login_required
      respond_to do |format|
        format.html { render "default/empty" }
        format.json {}
      end
    else
      respond_to do |format|
        format.html do
          @list = list
          store_preloaded(
            list.preload_key,
            MultiJson.dump(TopicListSerializer.new(list, scope: guardian)),
          )
          render "list/list"
        end
        format.json { render_serialized(list, TopicListSerializer) }
      end
    end
  end
end
