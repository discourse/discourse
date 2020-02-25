# frozen_string_literal: true

module Jobs
  class FixS3Etags < ::Jobs::Onceoff

    def execute_onceoff(args)
      [Upload, OptimizedImage].each do |model|
        sql = "UPDATE #{model.table_name} SET etag = REGEXP_REPLACE(etag, '\"', '', 'g') WHERE etag LIKE '\"%\"'"
        DB.exec(sql)
      end
    end
  end
end
