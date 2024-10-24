# frozen_string_literal: true

module Chat
  class Seeder
    def execute(args = {})
      return if !SiteSetting.needs_chat_seeded

      begin
        create_category_channel_from(SiteSetting.staff_category_id)
        create_category_channel_from(SiteSetting.general_category_id)
      rescue => error
        Rails.logger.warn("Error seeding chat category - #{error.inspect}")
      ensure
        SiteSetting.needs_chat_seeded = false
      end
    end

    def create_category_channel_from(category_id)
      category = Category.find_by(id: category_id)
      return if category.nil?

      category.create_chat_channel!(auto_join_users: true, name: category.name)
      category.custom_fields[Chat::HAS_CHAT_ENABLED] = true
      category.save!
    end
  end
end
