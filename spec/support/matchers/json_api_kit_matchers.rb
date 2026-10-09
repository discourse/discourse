# frozen_string_literal: true

require_relative "json_api_kit/anchor_on"
require_relative "json_api_kit/declare_model"
require_relative "json_api_kit/declare_namespace"
require_relative "json_api_kit/declare_type"
require_relative "json_api_kit/expose"
require_relative "json_api_kit/filter_on"
require_relative "json_api_kit/have_relationship"
require_relative "json_api_kit/paginate"
require_relative "json_api_kit/sort_by_default"
require_relative "json_api_kit/sort_on"

RSpec.shared_context "with a JSON:API resource" do
  subject(:resource) { described_class }
end

RSpec.configure { |config| config.include_context "with a JSON:API resource", type: :resource }

module JsonApiKitMatchers
  def declare_model(model)
    DeclareModel.new(model)
  end

  def declare_type(type)
    DeclareType.new(type)
  end

  def declare_namespace(namespace)
    DeclareNamespace.new(namespace)
  end

  def expose(*names)
    Expose.new(names)
  end

  def have_one(name)
    HaveRelationship.new(name, :one)
  end

  def have_many(name)
    HaveRelationship.new(name, :many)
  end

  def sort_on(*names)
    SortOn.new(names)
  end

  def sort_by_default(ordering)
    SortByDefault.new(ordering)
  end

  def filter_on(*names)
    FilterOn.new(names)
  end

  def anchor_on(*names)
    AnchorOn.new(names)
  end

  def paginate(default:, max:)
    Paginate.new(default:, max:)
  end
end
