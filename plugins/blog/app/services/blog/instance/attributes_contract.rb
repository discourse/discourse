# frozen_string_literal: true

# The blog fields the admin edits. Each tab sends only its own fields, so blank
# ones are left out of the changes.
class Blog::Instance::AttributesContract < Service::ContractBase
  FIELDS = %i[name slug url category_id description about path_format posts_per_page].freeze

  attribute :name, :string
  attribute :slug, :string
  attribute :url, :string
  attribute :category_id, :integer
  attribute :description, :string
  attribute :about, :string
  attribute :path_format, :string
  attribute :posts_per_page, :integer

  def blog_attributes
    attributes.symbolize_keys.slice(*FIELDS).compact
  end
end
