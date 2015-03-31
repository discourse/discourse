require_dependency 'has_errors'

class NewPostResult
  include HasErrors

  attr_reader :action
  attr_accessor :post

  def initialize(action, success=false)
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

  def success?
    @success
  end

  def failed?
    !@success
  end

end
