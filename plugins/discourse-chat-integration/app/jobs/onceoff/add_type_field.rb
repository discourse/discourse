# frozen_string_literal: true

module Jobs
  class DiscourseChatAddTypeField < ::Jobs::Onceoff
    def execute_onceoff(args)
      DiscourseChatIntegration::Rule.find_each { |rule| rule.save(validate: false) }
    end
  end
end
