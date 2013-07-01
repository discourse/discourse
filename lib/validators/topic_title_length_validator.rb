class TopicTitleLengthValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    title_validator(record).validate_each(record, attribute, value)
  end

  private

    def title_validator(record)
      length_range = if record.user.try(:admin?)
                       1..SiteSetting.max_topic_title_length
                     elsif record.private_message?
                       SiteSetting.private_message_title_length
                     else
                       SiteSetting.topic_title_length
                     end

      ActiveModel::Validations::LengthValidator.new({attributes: :title, in: length_range, allow_blank: true})
    end

end
