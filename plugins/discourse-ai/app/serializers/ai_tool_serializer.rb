# frozen_string_literal: true

class AiToolSerializer < ApplicationSerializer
  attributes :options, :id, :name, :help, :token_count

  def include_options?
    object.accepted_options.present?
  end

  def id
    object.to_s.split("::").last
  end

  def name
    object.name.humanize.titleize
  end

  def help
    object.help
  end

  def token_count
    DiscourseAi::Tokenizer::OpenAiCl100kTokenizer.size(object.signature.to_json)
  end

  def options
    options = {}
    object.accepted_options.each do |option|
      processed_option = {
        name: option.localized_name,
        description: option.localized_description,
        type: option.type,
      }
      processed_option[:values] = option.values if option.values.present?
      processed_option[:default] = option.default if option.default.present?
      options[option.name] = processed_option
    end
    options
  end
end
