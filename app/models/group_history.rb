class GroupHistory < ActiveRecord::Base
  belongs_to :group
  belongs_to :acting_user, class_name: 'User'
  belongs_to :target_user, class_name: 'User'

  validates :acting_user_id, presence: true
  validates :group_id, presence: true
  validates :action, presence: true

  def self.actions
    @actions ||= Enum.new(
      change_group_setting: 1,
      add_user_to_group: 2,
      remove_user_from_group: 3,
      make_user_group_owner: 4,
      remove_user_as_group_owner: 5
    )
  end

  def self.filters
    [
      :acting_user,
      :target_user,
      :action,
      :subject
    ]
  end

  def self.with_filters(group, params = {})
    records = self.includes(:acting_user, :target_user)
      .where(group_id: group.id)
      .order('group_histories.created_at DESC')

    if !params.blank?
      params = params.slice(*filters)
      records = records.where(action: self.actions[params[:action].to_sym]) unless params[:action].blank?
      records = records.where(subject: params[:subject]) unless params[:subject].blank?

      [:acting_user, :target_user].each do |filter|
        unless params[filter].blank?
          id = User.where(username_lower: params[filter]).pluck(:id)
          records = records.where("#{filter}_id" => id)
        end
      end
    end

    records
  end
end

# == Schema Information
#
# Table name: group_histories
#
#  id             :integer          not null, primary key
#  group_id       :integer          not null
#  acting_user_id :integer          not null
#  target_user_id :integer
#  action         :integer          not null
#  subject        :string
#  prev_value     :text
#  new_value      :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_group_histories_on_acting_user_id  (acting_user_id)
#  index_group_histories_on_action          (action)
#  index_group_histories_on_group_id        (group_id)
#  index_group_histories_on_target_user_id  (target_user_id)
#
