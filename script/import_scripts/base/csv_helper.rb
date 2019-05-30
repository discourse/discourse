# frozen_string_literal: true

module ImportScripts
  module CsvHelper
    class RowResolver
      def load(row)
        @row = row
      end

      def self.create(cols)
        Class.new(RowResolver).new(cols)
      end

      def initialize(cols)
        cols.each_with_index do |col, idx|
          self.class.public_send(:define_method, col.downcase.gsub(/[\W]/, '_').squeeze('_')) do
            @row[idx]
          end
        end
      end
    end

    def csv_parse(filename, col_sep = ',')
      first = true
      row = nil

      current_row = +""
      double_quote_count = 0

      File.open(filename).each_line do |line|

        line.strip!

        current_row << "\n" unless current_row.empty?
        current_row << line

        double_quote_count += line.scan('"').count

        next if double_quote_count % 2 == 1 # this row continues on a new line. don't parse until we have the whole row.

        raw = begin
                CSV.parse(current_row, col_sep: col_sep)
              rescue CSV::MalformedCSVError => e
                puts e.message
                puts "*" * 100
                puts "Bad row skipped, line is: #{line}"
                puts
                puts current_row
                puts
                puts "double quote count is : #{double_quote_count}"
                puts "*" * 100

                current_row = ""
                double_quote_count = 0

                next
              end[0]

        if first
          row = RowResolver.create(raw)

          current_row = ""
          double_quote_count = 0
          first = false
          next
        end

        row.load(raw)

        yield row

        current_row = ""
        double_quote_count = 0
      end
    end
  end
end
