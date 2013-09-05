#see: https://github.com/rails/rails/pull/12065
if rails4?
  module ActiveRecord
    class Result
      private
      def hash_rows
        @hash_rows ||=
          begin
            # We freeze the strings to prevent them getting duped when
            # used as keys in ActiveRecord::Base's @attributes hash
            columns = @columns.map { |c| c.dup.freeze }
            @rows.map { |row|
              # In the past we used Hash[columns.zip(row)]
              #  though elegant, the verbose way is much more efficient
              #  both time and memory wise cause it avoids a big array allocation
              #  this method is called a lot and needs to be micro optimised
              hash = {}

              index = 0
              length = columns.length

              while index < length
                hash[columns[index]] = row[index]
                index += 1
              end

              hash
            }
          end
      end
    end
  end
end
