# frozen_string_literal: true

module ReadOnlyHeader

  def check_readonly_mode
    @readonly_mode = Discourse.readonly_mode?
  end

  def add_readonly_header
    response.headers['Discourse-Readonly'] = 'true' if @readonly_mode
  end

end
