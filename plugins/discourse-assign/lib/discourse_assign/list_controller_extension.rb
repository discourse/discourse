# frozen_string_literal: true

module DiscourseAssign
  module ListControllerExtension
    extend ActiveSupport::Concern

    prepended { generate_message_route(:private_messages_assigned) }
  end
end
