class EmbeddableHost < ActiveRecord::Base
  validate :host_must_be_valid
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

  private

    def host_must_be_valid
      if host !~ /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,7}(:[0-9]{1,5})?(\/.*)?\Z/i &&
         host !~ /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/
        errors.add(:host, I18n.t('errors.messages.invalid'))
      end
    end
end

# == Schema Information
#
# Table name: embeddable_hosts
#
#  id          :integer          not null, primary key
#  host        :string           not null
#  category_id :integer          not null
#  created_at  :datetime
#  updated_at  :datetime
#
