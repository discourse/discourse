# frozen_string_literal: true

class ThemeFieldSerializer < ApplicationSerializer
  attributes :name, :target, :value, :error, :type_id, :upload_id, :url, :filename

  def include_url?
    object.upload
  end

  def include_upload_id?
    object.upload
  end

  def include_filename?
    object.upload
  end

  def url
    object.upload&.url
  end

  def filename
    object.upload&.original_filename
  end

  def include_value?
    @options[:include_value] || false
  end

  def target
    Theme.lookup_target(object.target_id)&.to_s
  end

  def include_error?
    object.error.present?
  end
end
