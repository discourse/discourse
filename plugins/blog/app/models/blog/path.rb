# frozen_string_literal: true

module ::Blog
  class Path < ActiveRecord::Base
    self.table_name = "blog_paths"
    belongs_to :publication
    belongs_to :blog, class_name: "Blog::Instance"
    normalizes :path, with: ->(path) { Publication.normalize_path(path) }
    validates :path, presence: true, uniqueness: { scope: :blog_id }
    before_validation { self.blog_id ||= publication&.blog_id }
  end
end

# == Schema Information
#
# Table name: blog_paths
#
#  id             :bigint           not null, primary key
#  path           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  blog_id        :bigint           not null
#  publication_id :bigint           not null
#
# Indexes
#
#  index_blog_paths_on_blog_id_and_path  (blog_id,path) UNIQUE
#  index_blog_paths_on_publication_id    (publication_id)
#
