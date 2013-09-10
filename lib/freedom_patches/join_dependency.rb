# see PR: https://github.com/rails/rails/pull/12185
#
class ActiveRecord::Associations::JoinDependency::JoinPart

  def extract_record(row)
    # Used to be: Hash[column_names_with_alias.map{|cn, an| [cn, row[an]]}]
    #  that is fairly inefficient cause all the values are first copied
    #  in to an array only to construct the Hash
    # This code is performance critical as it is called per row.
    hash = {}

    index = 0
    while index < column_names_with_alias.length do
      cn,an = column_names_with_alias[index]
      hash[cn] = row[an]
      index += 1
    end

    hash
  end
end

