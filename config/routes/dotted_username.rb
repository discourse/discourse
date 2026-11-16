# frozen_string_literal: true

concern :dotted_username do |options|
  verb = options.fetch(:verb)
  path = options.fetch(:path)
  path_constraints = options.fetch(:constraints, {})
  route_options = options.except(:verb, :path, :constraints)
  recognition_constraints = path_constraints.dup
  username = path_constraints[:username]
  recognition_constraints[:username] = [username] if username.is_a?(Regexp)

  match path, via: verb, **route_options.except(:as), as: nil, constraints: recognition_constraints

  constraints ->(_request) { false } do
    match path, via: verb, **route_options, anchor: false, constraints: path_constraints
  end
end
