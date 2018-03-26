class TopicPublisher

  def initialize(topic, published_by, category_id)
    @topic = topic
    @published_by = published_by
    @category_id = category_id
  end

  def publish!
    TopicTimestampChanger.new(timestamp: Time.zone.now, topic: @topic).change! do
      if @topic.private_message?
        @topic = TopicConverter.new(@topic, @published_by)
          .convert_to_public_topic(@category_id)
      else
        @topic.change_category_to_id(@category_id)
      end

      @topic.update_columns(visible: true)

      StaffActionLogger.new(@published_by).log_topic_published(@topic)

      # Clean up any publishing artifacts
      SharedDraft.where(topic: @topic).delete_all
      TopicTimer.where(topic: @topic).update_all(
        deleted_at: DateTime.now,
        deleted_by_id: @published_by.id
      )

      op = @topic.first_post
      if op.present?
        op.revisions.delete_all
        op.update_column(:version, 1)
        op.update_column(:public_version, 1)
      end
    end

    MessageBus.publish("/topic/#{@topic.id}", reload_topic: true, refresh_stream: true)

    @topic
  end

end
