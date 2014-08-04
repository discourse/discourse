class IncomingReferer < ActiveRecord::Base
end

# == Schema Information
#
# Table name: incoming_referers
#
#  id                 :integer          not null, primary key
#  url                :string(1000)     not null
#  path               :string(1000)     not null
#  incoming_domain_id :integer          not null
#
# Indexes
#
#  index_incoming_referers_on_path_and_incoming_domain_id  (path,incoming_domain_id) UNIQUE
#
