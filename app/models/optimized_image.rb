class OptimizedImage < ActiveRecord::Base
  belongs_to :upload

  def filename
    "#{sha[0..2]}/#{sha[3..5]}/#{sha[6..16]}_#{width}x#{height}#{ext}"
  end
end
