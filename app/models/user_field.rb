# frozen_string_literal: true

class UserField < ActiveRecord::Base
  include AnonCacheInvalidator
  include HasDeprecatedColumns
  include HasSanitizableFields

  FLAG_ATTRIBUTES = %w[editable show_on_profile show_on_signup show_on_user_card searchable].freeze

  deprecate_column :required, drop_from: "3.3"
  self.ignored_columns += %i[field_type]

  validates_presence_of :description
  validates_presence_of :name, unless: -> { field_type == "confirm" }
  has_many :user_field_options, dependent: :destroy
  has_one :directory_column, dependent: :destroy
  accepts_nested_attributes_for :user_field_options

  before_save :sanitize_description
  after_create :update_required_fields_version
  after_update :update_required_fields_version, if: -> { saved_change_to_requirement? }
  after_save :queue_index_search

  scope :public_fields, -> { where(show_on_profile: true).or(where(show_on_user_card: true)) }
  scope :required, -> { not_optional }
  scope :user_editable_text_fields, -> { where(field_type: %w[text textarea]) }

  enum :requirement, { optional: 0, for_all_users: 1, on_signup: 2 }.freeze
  enum :field_type_enum, { text: 0, confirm: 1, dropdown: 2, multiselect: 3, textarea: 4 }.freeze
  alias_attribute :field_type, :field_type_enum

  def self.max_length
    2048
  end

  def required?
    !optional?
  end

  def queue_index_search
    Jobs.enqueue(:index_user_fields_for_search, user_field_id: self.id)
  end

  private

  def update_required_fields_version
    return if !for_all_users?

    UserRequiredFieldsVersion.create
    Discourse.request_refresh!
  end

  def sanitize_description
    if description_changed?
      self.description = sanitize_field(self.description, additional_attributes: ["target"])
    end
  end
end

# == Schema Information
#
# Table name: user_fields
#
#  id                :integer          not null, primary key
#  description       :string           not null
#  editable          :boolean          default(FALSE), not null
#  external_name     :string
#  external_type     :string
#  field_type_enum   :integer          not null
#  name              :string           not null
#  position          :integer          default(0)
#  required          :boolean          default(TRUE), not null
#  requirement       :integer          default("optional"), not null
#  searchable        :boolean          default(FALSE), not null
#  show_on_profile   :boolean          default(FALSE), not null
#  show_on_signup    :boolean          default(TRUE), not null
#  show_on_user_card :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
