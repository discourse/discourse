# frozen_string_literal: true

class RouteMatcher
  attr_reader :actions, :params, :methods, :aliases, :formats, :allowed_param_values

  def initialize(actions: nil, params: nil, methods: nil, formats: nil, aliases: nil, allowed_param_values: nil)
    @actions = Array(actions) if actions
    @params = Array(params) if params
    @methods = Array(methods) if methods
    @formats = Array(formats) if formats
    @aliases = aliases
    @allowed_param_values = allowed_param_values
  end

  # Return an identical route matcher, with the allowed_param_values replaced
  def with_allowed_param_values(new_allowed_param_values)
    RouteMatcher.new(
      actions: actions,
      params: params,
      methods: methods,
      formats: formats,
      aliases: aliases,
      allowed_param_values: new_allowed_param_values
    )
  end

  def match?(env:)
    request = ActionDispatch::Request.new(env)

    action_allowed?(request) &&
      params_allowed?(request) &&
      method_allowed?(request) &&
      format_allowed?(request)
  end

  private

  def action_allowed?(request)
    return true if actions.nil? # actions are unrestricted

    # message_bus is not a rails route, special handling
    return true if actions.include?("message_bus") && request.fullpath =~ /^\/message-bus\/.*\/poll/

    path_params = request.path_parameters
    actions.include? "#{path_params[:controller]}##{path_params[:action]}"
  end

  def params_allowed?(request)
    return true if params.nil? || allowed_param_values.blank? # params are unrestricted

    requested_params = request.parameters

    params.all? do |param|
      param_alias = aliases&.[](param)
      allowed_values = [allowed_param_values[param.to_s]].flatten

      value = requested_params[param.to_s]
      alias_value = requested_params[param_alias.to_s]

      return false if value.present? && alias_value.present?

      value = value || alias_value
      value = extract_category_id(value) if param_alias == :category_slug_path_with_id

      allowed_values.blank? || allowed_values.include?(value)
    end
  end

  def extract_category_id(category_slug_with_id)
    parts = category_slug_with_id.split('/')
    !parts.empty? && parts.last =~ /\A\d+\Z/ ? parts.pop : nil
  end

  def method_allowed?(request)
    return true if methods.nil?
    request_method = request.request_method&.downcase&.to_sym
    methods.include?(request_method)
  end

  def format_allowed?(request)
    return true if formats.nil?
    request_format = request.formats&.first&.symbol
    formats.include?(request_format)
  end
end
