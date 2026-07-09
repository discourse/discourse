# frozen_string_literal: true

class AiPostImageDescription < ActiveRecord::Base
  belongs_to :post
  belongs_to :upload
end

# == Schema Information
#
# Table name: ai_post_image_descriptions
#
#  id                :bigint           not null, primary key
#  attempts          :integer          default(0), not null
#  base62_sha1       :string(27)       not null
#  description       :text
#  last_attempted_at :datetime
#  last_error        :text
#  locale            :string(20)       not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  post_id           :integer          not null
#  upload_id         :integer          not null
#
# Indexes
#
#  idx_ai_post_image_descriptions_lookup  (post_id,locale,base62_sha1) UNIQUE
#  idx_ai_post_image_descriptions_reuse   (base62_sha1,locale)
#
