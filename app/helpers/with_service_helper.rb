# frozen_string_literal: true

module WithServiceHelper
  def result
    @_result
  end

  # @param service [Class] A class including {Service::Base}
  # @param dependencies [kwargs] Any additional params to load into the service context,
  #   in addition to controller @params.
  def with_service(service, **dependencies, &block)
    object = self
    ServiceRunner.call(
      service,
      object,
      **dependencies,
      &proc { instance_exec(&(block || proc {})) }
    )
  end

  def run_service(service, dependencies)
    params = self.try(:params) || ActionController::Parameters.new

    @_result =
      service.call(params.to_unsafe_h.merge(guardian: self.try(:guardian) || nil, **dependencies))
  end
end
