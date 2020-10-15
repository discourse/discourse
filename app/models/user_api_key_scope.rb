# frozen_string_literal: true

class UserApiKeyScope < ActiveRecord::Base
end

# == Schema Information
#
# Table name: user_api_key_scopes
#
#  id              :bigint           not null, primary key
#  user_api_key_id :integer          not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_user_api_key_scopes_on_user_api_key_id  (user_api_key_id)
#
