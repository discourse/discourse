class CategoryGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group

  delegate :name, to: :group, prefix: true

  def self.permission_types
    @permission_types ||= Enum.new(full: 1, create_post: 2, readonly: 3)
  end

end

# == Schema Information
#
# Table name: category_groups
#
#  id              :integer          not null, primary key
#  category_id     :integer          not null
#  group_id        :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  permission_type :integer          default(1)
#
