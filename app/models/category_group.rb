class CategoryGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group
end

# == Schema Information
#
# Table name: category_groups
#
#  id          :integer          not null, primary key
#  category_id :integer          not null
#  group_id    :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

