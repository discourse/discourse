class IncomingDomain < ActiveRecord::Base
end

# == Schema Information
#
# Table name: incoming_domains
#
#  id    :integer          not null, primary key
#  name  :string(100)      not null
#  https :boolean          default(FALSE), not null
#  port  :integer          not null
#
# Indexes
#
#  index_incoming_domains_on_name_and_https_and_port  (name,https,port) UNIQUE
#
