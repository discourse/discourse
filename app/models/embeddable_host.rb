class EmbeddableHost < ActiveRecord::Base
  validates_format_of :host, :with => /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?\Z/i
  belongs_to :category

  before_validation do
    self.host.sub!(/^https?:\/\//, '')
    self.host.sub!(/\/.*$/, '')
  end

  def self.record_for_host(host)
    uri = URI(host) rescue nil
    return false unless uri.present?

    host = uri.host
    return false unless host.present?

    where("lower(host) = ?", host).first
  end

  def self.host_allowed?(host)
    record_for_host(host).present?
  end

end

# == Schema Information
#
# Table name: embeddable_hosts
#
#  id          :integer          not null, primary key
#  host        :string(255)      not null
#  category_id :integer          not null
#  created_at  :datetime
#  updated_at  :datetime
#
