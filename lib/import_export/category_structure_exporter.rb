# frozen_string_literal: true

module ImportExport
  class CategoryStructureExporter < BaseExporter

    def initialize(include_group_users = false)
      @include_group_users = include_group_users

      @export_data = {
        groups: [],
        categories: []
      }
      @export_data[:users] = [] if @include_group_users
    end

    def perform
      puts "Exporting all the categories...", ""
      export_categories!
      export_category_groups!
      export_group_users! if @include_group_users

      self
    end

    def default_filename_prefix
      "category-structure-export"
    end

  end
end
