# frozen_string_literal: true

class CategoryUploadSerializer < ApplicationSerializer
  root 'category_upload'

  attributes :id, :url, :width, :height
end
