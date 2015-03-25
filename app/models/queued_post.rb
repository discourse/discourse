class QueuedPost < ActiveRecord::Base

  class InvalidStateTransition < StandardError; end;

  serialize :post_options, JSON

  belongs_to :user
  belongs_to :topic
  belongs_to :approved_by, class_name: "User"
  belongs_to :rejected_by, class_name: "User"

  def self.attributes_by_queue
    @attributes_by_queue ||= {
      base: [:archetype,
             :via_email,
             :raw_email,
             :auto_track,
             :custom_fields,
             :cooking_options,
             :cook_method,
             :image_sizes],
      new_post: [:reply_to_post_number],
      new_topic: [:title, :category, :meta_data, :archetype],
    }
  end

  def self.states
    @states ||= Enum.new(:new, :approved, :rejected)
  end

  def reject!(rejected_by)
    change_to!(:rejected, rejected_by)
  end

  def create_options
    opts = {raw: raw}
    post_attributes.each {|a| opts[a] = post_options[a.to_s] }

    opts[:topic_id] = topic_id if topic_id
    opts
  end

  def approve!(approved_by)
    created_post = nil
    QueuedPost.transaction do
      change_to!(:approved, approved_by)

      creator = PostCreator.new(user, create_options)
      created_post = creator.create
    end
    created_post
  end

  private
    def post_attributes
      [QueuedPost.attributes_by_queue[:base], QueuedPost.attributes_by_queue[queue.to_sym]].flatten.compact
    end

    def change_to!(state, changed_by)
      state_val = QueuedPost.states[state]

      updates = { state: state_val,
                  "#{state}_by_id" => changed_by.id,
                  "#{state}_at" => Time.now }

      # We use an update with `row_count` trick here to avoid stampeding requests to
      # update the same row simultaneously. Only one state change should go through and
      # we can use the DB to enforce this
      row_count = QueuedPost.where('id = ? AND state <> ?', id, state_val).update_all(updates)
      raise InvalidStateTransition.new if row_count == 0

      # Update the record in memory too, and clear the dirty flag
      updates.each {|k, v| send("#{k}=", v) }
      changes_applied
    end

end
