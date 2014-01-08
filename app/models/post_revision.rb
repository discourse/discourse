class PostRevision < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  serialize :modifications, Hash
end
