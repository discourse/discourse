# frozen_string_literal: true

class IncomingReferer < ActiveRecord::Base
  belongs_to :incoming_domain

  def self.add!(opts)
    domain_id = opts[:incoming_domain_id]
    domain_id ||= opts[:incoming_domain].id
    path = opts[:path]

    current = find_by(path: path, incoming_domain_id: domain_id)
    return current if current

    begin
      current = create!(path: path, incoming_domain_id: domain_id)
    rescue ActiveRecord::RecordNotUnique
      # does not matter
    end

    current || find_by(path: path, incoming_domain_id: domain_id)
  end
end

# == Schema Information
#
# Table name: incoming_referers
#
#  id                 :integer          not null, primary key
#  path               :string(1000)     not null
#  incoming_domain_id :integer          not null
#
# Indexes
#
#  index_incoming_referers_on_path_and_incoming_domain_id  (path,incoming_domain_id) UNIQUE
#
