require 'discourse_plugin'

module DiscoursePoll
  class Plugin < DiscoursePlugin

    MAX_SORT_ORDER = 2147483647
    POLL_OPTIONS = {private_poll: 1, single_vote: 1}
    
    def setup
      
      # Add our Assets
      register_js('discourse_poll')
      register_css('discourse_poll')

      # Create the poll archetype
      register_archetype('poll', POLL_OPTIONS)

      # Callbacks
      listen_for(:before_create_post)
    end

    # Callbacks below
    def before_create_post(post)
      return unless post.archetype == 'poll'
      if post.post_number == 1
        post.sort_order = 1
      else
        post.sort_order = DiscoursePoll::Plugin::MAX_SORT_ORDER
      end         
    end

    module TopicViewSerializerMixin

      def self.included(base)
        base.attributes :private_poll, :single_vote  
      end
      
      def private_poll
        object.topic.has_meta_data_boolean?(:private_poll)
      end

      def single_vote
        object.topic.has_meta_data_boolean?(:single_vote)
      end

    end

  end
end
