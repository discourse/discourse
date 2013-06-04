class TopicTitleLengthValidator < ActiveModel::EachValidator

  def initialize(options)
    @topic_title_validator = ActiveModel::Validations::LengthValidator.new({attributes: :title, in: SiteSetting.topic_title_length, allow_blank: true})
    @private_message_title_validator = ActiveModel::Validations::LengthValidator.new({attributes: :title, in: SiteSetting.private_message_title_length, allow_blank: true})
    super
  end

  def validate_each(record, attribute, value)
    if record.private_message?
      @private_message_title_validator.validate_each(record, attribute, value)
    else
      @topic_title_validator.validate_each(record, attribute, value)
    end
  end
end
