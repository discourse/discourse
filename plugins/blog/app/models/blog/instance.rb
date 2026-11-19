# frozen_string_literal: true

module ::Blog
  # One blog on the site. Named Instance because a Blog::Blog model would shadow
  # the namespace for every Blog:: reference inside it.
  class Instance < ActiveRecord::Base
    self.table_name = "blog_instances"

    SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    URL_FORMAT = %r{\Ahttps://[a-z0-9.-]+(?::[0-9]+)?\z}

    belongs_to :category, optional: true

    normalizes :url, with: ->(url) { url.presence }

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true, format: { with: SLUG_FORMAT }
    validates :url, uniqueness: true, format: { with: URL_FORMAT }, allow_nil: true
    validates :category_id, uniqueness: true, allow_nil: true
    validates :posts_per_page, numericality: { only_integer: true, in: 1..30 }
    validates :is_default, uniqueness: true, if: :is_default?
    validate :path_format_valid

    scope :ordered, -> { order(:position, :id) }

    private

    def path_format_valid
      validator = PathFormatValidator.new
      return if validator.valid_value?(path_format)
      errors.add(:path_format, validator.error_message)
    end
  end
end

# == Schema Information
#
# Table name: blog_instances
#
#  id             :bigint           not null, primary key
#  about          :text             default(""), not null
#  active_theme   :jsonb
#  description    :text             default(""), not null
#  is_default     :boolean          default(FALSE), not null
#  name           :string           not null
#  path_format    :string           default("/{slug}"), not null
#  position       :integer          default(0), not null
#  posts_per_page :integer          default(10), not null
#  slug           :string           not null
#  url            :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  category_id    :integer
#
# Indexes
#
#  index_blog_instances_on_category_id  (category_id) UNIQUE
#  index_blog_instances_on_is_default   (is_default) UNIQUE WHERE is_default
#  index_blog_instances_on_slug         (slug) UNIQUE
#  index_blog_instances_on_url          (url) UNIQUE
#
