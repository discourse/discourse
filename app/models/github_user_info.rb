class GithubUserInfo < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: github_user_infos
#
#  id             :integer          not null, primary key
#  user_id        :integer          not null
#  screen_name    :string           not null
#  github_user_id :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_github_user_infos_on_github_user_id  (github_user_id) UNIQUE
#  index_github_user_infos_on_user_id         (user_id) UNIQUE
#
