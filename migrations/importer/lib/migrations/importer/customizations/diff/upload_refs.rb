# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Diff
        # Upload ids referenced by a row, by column name convention and by the
        # data_type of site/theme settings.
        module UploadRefs
          def self.call(table, row_hash)
            ids = []
            row_hash.each { |col, val| ids << val.to_i if upload_column?(col) && val && val != "" }

            case table
            when "site_settings"
              type = row_hash["data_type"].to_i
              value = row_hash["value"].to_s
              ids << value.to_i if type == Defaults::SITE_SETTING_UPLOAD_TYPE && value != ""
              if type == Defaults::SITE_SETTING_UPLOAD_LIST_TYPE
                ids.concat(value.split("|").map(&:to_i))
              end
            when "theme_settings"
              value = row_hash["value"].to_s
              if row_hash["data_type"].to_i == Defaults::THEME_SETTING_UPLOAD_TYPE && value != ""
                ids << value.to_i
              end
            end

            ids.reject(&:zero?)
          end

          def self.upload_column?(name)
            name.end_with?("_id") && name.include?("upload")
          end
        end
      end
    end
  end
end
