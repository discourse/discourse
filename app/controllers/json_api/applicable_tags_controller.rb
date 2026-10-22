# frozen_string_literal: true

module JsonApi
  class ApplicableTagsController < JsonApiKit::BaseController
    resource TagResource.collection(:applicable)
  end
end
