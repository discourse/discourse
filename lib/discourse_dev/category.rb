# frozen_string_literal: true

require 'discourse_dev/record'
require 'rails'
require 'faker'

module DiscourseDev
  class Category < Record

    def initialize
      super(::Category, DiscourseDev.config.category[:count])
      @parent_category_ids = ::Category.where(parent_category_id: nil).pluck(:id)
    end

    def data
      name = Faker::Discourse.unique.category
      parent_category_id = nil

      if Faker::Boolean.boolean(true_ratio: 0.6)
        offset = Faker::Number.between(from: 0, to: @parent_category_ids.count - 1)
        parent_category_id = @parent_category_ids[offset]
        @permissions = ::Category.find(parent_category_id).permissions_params.presence
      else
        @permissions = nil
      end

      {
        name: name,
        description: Faker::Lorem.paragraph,
        user_id: ::Discourse::SYSTEM_USER_ID,
        color: Faker::Color.hex_color.last(6),
        parent_category_id: parent_category_id
      }
    end

    def permissions
      return @permissions if @permissions.present?
      return { everyone: :full } if Faker::Boolean.boolean(true_ratio: 0.75)

      permission = {}
      group = Group.random
      permission[group.id] = Faker::Number.between(from: 1, to: 3)

      permission
    end

    def create!
      super do |category|
        category.set_permissions(permissions)
        category.save!

        @parent_category_ids << category.id if category.parent_category_id.blank?
      end
    end

    def self.random
      super(::Category)
    end
  end
end
