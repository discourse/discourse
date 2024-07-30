# frozen_string_literal: true

class ServiceJob < ::Jobs::Base
  include WithServiceHelper

  def run_service(service, dependencies)
    @_result = service.call(dependencies)
  end
end
