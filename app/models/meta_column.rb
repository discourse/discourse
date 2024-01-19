class MetaColumn < ActiveRecord::Base
  belongs_to :meta_schema
  belongs_to :detailable, polymorphic: true
end
