# frozen_string_literal: true

class PostCustomField < ActiveRecord::Base
  belongs_to :post
end

# == Schema Information
#
# Table name: post_custom_fields
#
#  id         :integer          not null, primary key
#  post_id    :integer          not null
#  name       :string(256)      not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  idx_post_custom_fields_akismet                (post_id) WHERE (((name)::text = 'AKISMET_STATE'::text) AND (value = 'needs_review'::text))
#  index_post_custom_fields_on_name_and_value    (name, "left"(value, 200))
#  index_post_custom_fields_on_notice_args       (post_id) UNIQUE WHERE ((name)::text = 'notice_args'::text)
#  index_post_custom_fields_on_notice_type       (post_id) UNIQUE WHERE ((name)::text = 'notice_type'::text)
#  index_post_custom_fields_on_post_id           (post_id) UNIQUE WHERE ((name)::text = 'missing uploads'::text)
#  index_post_custom_fields_on_post_id_and_name  (post_id,name)
#  index_post_id_where_missing_uploads_ignored   (post_id) UNIQUE WHERE ((name)::text = 'missing uploads ignored'::text)
#  post_custom_field_broken_images_idx           (post_id) UNIQUE WHERE ((name)::text = 'broken_images'::text)
#  post_custom_field_downloaded_images_idx       (post_id) UNIQUE WHERE ((name)::text = 'downloaded_images'::text)
#  post_custom_field_large_images_idx            (post_id) UNIQUE WHERE ((name)::text = 'large_images'::text)
#
