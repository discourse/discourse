# frozen_string_literal: true

class NewPostResult
  include HasErrors

  attr_reader :action

  attr_accessor :reason
  attr_accessor :post
  attr_accessor :reviewable
  attr_accessor :pending_count
  attr_accessor :route_to
  attr_accessor :message

  def initialize(action, success = false)
    @action = action
    @success = success
  end

  def check_errors_from(obj)
    if obj.errors.empty?
      @success = true
    else
      add_errors_from(obj)
    end
  end

  def check_errors(arr)
    if arr.empty?
      @success = true
    else
      arr.each { |e| errors.add(:base, e) unless errors[:base].include?(e) }
    end
  end

  def queued_post
    Discourse.deprecate(
      "NewPostManager#queued_post is deprecated. Please use #reviewable instead.",
      output_in_test: true
    )

    reviewable
  end

  def success?
    @success
  end

  def failed?
    !@success
  end

end
