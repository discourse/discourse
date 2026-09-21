# frozen_string_literal: true

class RouteMatcher
  PATH_PARAMETERS = "_DISCOURSE_REQUEST_PATH_PARAMETERS"

  attr_reader :actions, :params, :path_params, :methods, :aliases, :formats, :allowed_param_values

  def initialize(
    actions: nil,
    params: nil,
    path_params: nil,
    methods: nil,
    formats: nil,
    aliases: nil,
    allowed_param_values: nil
  )
    @actions = Array(actions) if actions
    @params = Array(params) if params
    @path_params = Array(path_params) if path_params
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
      path_params: path_params,
      methods: methods,
      formats: formats,
      aliases: aliases,
      allowed_param_values: new_allowed_param_values,
    )
  end

  def match?(env:)
    request = ActionDispatch::Request.new(env)

    action_allowed?(request) && params_allowed?(request) && method_allowed?(request) &&
      format_allowed?(request)
  end

  private

  def action_allowed?(request)
    return true if actions.nil? # actions are unrestricted

    # message_bus is not a rails route, special handling
    return true if actions.include?("message_bus") && request.fullpath =~ %r{\A/message-bus/.*/poll}

    # logster is not a rails route, special handling
    return true if actions.include?(Logster::Web) && request.fullpath =~ %r{\A/logs/.*\.json\z}

    recognized_params = path_params_from_request(request)
    actions.include? "#{recognized_params[:controller]}##{recognized_params[:action]}"
  end

  def params_allowed?(request)
    return true if allowed_param_values.blank?

    ordinary_params = Array(params).map(&:to_sym) - Array(path_params).map(&:to_sym)
    ordinary_params_allowed?(request, ordinary_params) && path_params_allowed?(request)
  end

  def ordinary_params_allowed?(request, ordinary_params)
    return true if ordinary_params.empty?

    requested_params = request.parameters

    ordinary_params.all? do |param|
      param_alias = param_alias_for(param)
      allowed_values = [allowed_param_values.fetch(param.to_s, [])].flatten

      value = requested_params[param.to_s]
      alias_value = requested_params[param_alias.to_s]

      return false if value.present? && alias_value.present?

      value = value || alias_value
      value = extract_category_id(value) if param_alias == :category_slug_path_with_id

      allowed_values.blank? || allowed_values.include?(value)
    end
  end

  def path_params_allowed?(request)
    return true if path_params.nil?

    requested_params = path_params_from_request(request)

    path_params.all? do |param|
      allowed_values = [allowed_param_values.fetch(param.to_s, [])].flatten
      next true if allowed_values.blank?

      param_alias = param_alias_for(param)
      value_present, value = path_parameter(requested_params, param)
      alias_present, alias_value = path_parameter(requested_params, param_alias)

      next false if value_present && alias_present
      next false unless value_present || alias_present

      requested_value = value_present ? value : alias_value
      scalar_path_value?(requested_value) && allowed_values.include?(requested_value)
    end
  end

  def param_alias_for(param)
    aliases&.[](param) || aliases&.[](param.to_s) || aliases&.[](param.to_sym)
  end

  def path_parameter(requested_params, param)
    return false, nil if param.nil?

    string_key = param.to_s
    if requested_params.key?(string_key)
      value = requested_params[string_key]
      return true, value unless value.nil?
    end

    symbol_key = param.to_sym
    if requested_params.key?(symbol_key)
      value = requested_params[symbol_key]
      return true, value unless value.nil?
    end
    [false, nil]
  end

  def scalar_path_value?(value)
    value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric) || value == true ||
      value == false
  end

  def extract_category_id(category_slug_with_id)
    parts = category_slug_with_id&.split("/")
    parts.present? && parts.last.match?(/\A\d+\Z/) ? parts.pop : nil
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

  def path_params_from_request(request)
    return request.path_parameters if request.path_parameters.present?

    request.env[PATH_PARAMETERS] ||= begin
      Rails.application.routes.recognize_path(request.path_info, method: request.request_method)
    rescue ActionController::RoutingError
      {}
    end
  end
end
