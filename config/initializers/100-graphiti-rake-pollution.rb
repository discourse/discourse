# frozen_string_literal: true

# JSON:API spike workaround (see
# plugins/discourse-data-explorer/docs/api-modernization-exploration.md).
#
# graphiti-rails 0.4.1 ships lib/tasks/graphiti.rake which defines helper
# methods (`session`, `setup_rails!`, `make_request`) at the top level of the
# rake file — rake namespaces are not lexical scopes, so they all become
# private methods on Object once tasks are loaded. `Object#session` then
# shadows the request-spec `session` helper (every spec doing
# `session[:key]` blows up with "undefined method '[]' for an instance of
# ActionDispatch::Integration::Session").
#
# Scrub those methods right after any task loading, guarded by source
# location so we only ever remove graphiti's definitions.
module ScrubGraphitiRakePollution
  POLLUTING_METHODS = %i[session setup_rails! make_request].freeze

  def load_tasks(*)
    super.tap do
      POLLUTING_METHODS.each do |name|
        next unless Object.private_method_defined?(name) || Object.method_defined?(name)

        source = Object.instance_method(name).source_location&.first.to_s
        Object.send(:remove_method, name) if source.include?("graphiti.rake")
      end
    end
  end
end

Rails.application.singleton_class.prepend(ScrubGraphitiRakePollution)
