class ApiKey < ActiveRecord::Base
  belongs_to :user
  belongs_to :created_by, class_name: User

  validates_presence_of :key

  def regenerate!(updated_by)
    self.key = SecureRandom.hex(32)
    self.created_by = updated_by
    save!
  end

  def self.create_master_key
    api_key = ApiKey.find_by(user_id: nil, hidden: false)
    if api_key.blank?
      api_key = ApiKey.create(key: SecureRandom.hex(32), created_by: Discourse.system_user)
    end
    api_key
  end

end

# == Schema Information
#
# Table name: api_keys
#
#  id            :integer          not null, primary key
#  key           :string(64)       not null
#  user_id       :integer
#  created_by_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  allowed_ips   :inet             is an Array
#  hidden        :boolean          default(FALSE), not null
#
# Indexes
#
#  index_api_keys_on_key      (key)
#  index_api_keys_on_user_id  (user_id) UNIQUE
#
