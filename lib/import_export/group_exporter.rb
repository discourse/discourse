# frozen_string_literal: true

module ImportExport
  class GroupExporter < BaseExporter

    def initialize(include_group_users = false)
      @include_group_users = include_group_users

      @export_data = {
        groups: []
      }
      @export_data[:users] = [] if @include_group_users
    end

    def perform
      puts "Exporting all user groups...", ""
      export_groups!
      export_group_users! if @include_group_users

      self
    end

    def default_filename_prefix
      "groups-export"
    end

  end
end
