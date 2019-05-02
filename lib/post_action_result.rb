# frozen_string_literal: true

require_dependency 'has_errors'

class PostActionResult
  include HasErrors

  attr_accessor :success

  def initialize
    @success = false
  end

  def success?
    @success
  end

  def failed?
    !success
  end
end
