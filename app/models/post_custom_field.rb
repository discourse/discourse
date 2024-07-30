# frozen_string_literal: true

class PostCustomField < ActiveRecord::Base
  include CustomField

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
#  index_post_custom_fields_on_name_and_value             (name, "left"(value, 200))
#  index_post_custom_fields_on_notice                     (post_id) UNIQUE WHERE ((name)::text = 'notice'::text)
#  index_post_custom_fields_on_post_id                    (post_id) UNIQUE WHERE ((name)::text = 'missing uploads'::text)
#  index_post_custom_fields_on_post_id_and_name           (post_id,name)
#  index_post_custom_fields_on_stalled_wiki_triggered_at  (post_id) UNIQUE WHERE ((name)::text = 'stalled_wiki_triggered_at'::text)
#  index_post_id_where_missing_uploads_ignored            (post_id) UNIQUE WHERE ((name)::text = 'missing uploads ignored'::text)
#
