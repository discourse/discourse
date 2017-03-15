class WebHookEventType < ActiveRecord::Base
  TOPIC = 1
  POST = 2
  USER = 3

  has_and_belongs_to_many :web_hooks

  default_scope { order('id ASC') }

  validates :name, presence: true, uniqueness: true

  module TopicType
    def self.load_record(topic_id)
      TopicView.new(topic_id.to_i, Discourse.system_user) rescue nil
    end

    def self.serializer
      WebHookTopicViewSerializer
    end
  end

  module PostType
    def self.load_record(post_id)
      Post.find_by(id: post_id.to_i)
    end

    def self.serializer
      WebHookPostSerializer
    end
  end

  module UserType
    def self.load_record(user_id)
      User.find_by(id: user_id.to_i)
    end

    def self.serializer
      WebHookUserSerializer
    end
  end
end

# == Schema Information
#
# Table name: web_hook_event_types
#
#  id   :integer          not null, primary key
#  name :string           not null
#
