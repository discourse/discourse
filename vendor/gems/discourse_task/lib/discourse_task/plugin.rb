require 'discourse_plugin'

module DiscourseTask

  class Plugin < DiscoursePlugin

    def self.archetype
      'task'
    end

    def setup
      # Add our Assets
      register_js('discourse_task')
      register_css('discourse_task')

      # Add the archetype
      register_archetype(DiscourseTask::Plugin.archetype)

    end

    module TopicViewSerializerMixin
      def self.included(base)
        base.attributes :can_complete_task, :complete, :completed_at
      end

      def can_complete_task
        scope.can_complete_task?(object.topic)
      end

      def complete
        object.topic.has_meta_data_boolean?(:complete)
      end

      def completed_at
        dt = Date.parse(object.topic.meta_data_string(:completed_at)).strftime("%d %b, %Y")
      end
      def include_completed_at?
        object.topic.meta_data_string(:completed_at).present?
      end

    end

    module GuardianMixin

      # We need to be able to determine if a user can complete a task
      def can_complete_task?(topic)
        return false if @user.blank?
        return false if topic.blank?
        return false unless topic.archetype == DiscourseTask::Plugin.archetype
        return true if @user.moderator?
        return true if @user.admin?

        # The OP can complete the topic
        return @user == topic.user
      end

    end

    module TopicsControllerMixin

      def complete
        topic = Topic.where(id: params[:topic_id]).first
        guardian.ensure_can_complete_task!(topic)

        Topic.transaction do
          if params[:complete] == 'true'
            topic.update_meta_data(complete: true, completed_at: Time.now)
            topic.add_moderator_post(current_user, I18n.t(:'task.completed'))
          else
            topic.update_meta_data(complete: false)
            topic.add_moderator_post(current_user, I18n.t(:'task.reversed'))
          end
        end

        render nothing: true
      end

    end

    module TopicListItemSerializerMixin
      def self.included(base)
        base.attributes :complete
      end

      def complete
        object.has_meta_data_boolean?(:complete)
      end
    end

  end

end
