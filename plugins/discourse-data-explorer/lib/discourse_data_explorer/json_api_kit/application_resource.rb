# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The application-owned abstract base (the ApplicationRecord convention):
    # resources inherit from here, never from ResourceBase directly, so
    # app-wide declarations (shared attributes, page defaults, …) have a home.
    # Declarations made here are inherited by every resource.
    class ApplicationResource < ResourceBase
    end
  end
end
