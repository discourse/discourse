module DroppedCategoryColumns
  extend ActiveSupport::Concern

  COLUMNS = %w{
    logo_url
    background_url
  }.each(&:freeze)

  class_methods do
    def columns
      if dropped?
        super()
      else
        super().reject { |column| COLUMNS.include?(column.name) }
      end
    end

    def columns_exist_sql
      <<~SQL
      SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
      WHERE table_schema = 'public'
      AND table_name = 'categories'
      AND column_name = '#{COLUMNS.first}'
      SQL
    end

    private

    def dropped?
      @dropped ||= begin
        Category.exec_sql(columns_exist_sql).to_a.length == 0
      end
    end
  end
end
