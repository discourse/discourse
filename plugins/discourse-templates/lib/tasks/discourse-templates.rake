# frozen_string_literal: true

desc "Migrate data from discourse-canned-replies to discourse-templates"
task "discourse-templates:migrate-from-canned-replies" => :environment do
  ENV["RAILS_DB"] ? migrate_data : migrate_data_all_sites
end

desc "Purge old data from canned replies"
task "discourse-templates:purge-old-canned-replies-data" => :environment do
  ENV["RAILS_DB"] ? purge_old_data : purge_old_data_all_sites
end

def create_category
  old_settings_canned_replies_groups =
    SiteSetting.find_by(name: "canned_replies_groups")&.value || ""
  old_settings_canned_replies_everyone_enabled =
    SiteSetting.find_by(name: "canned_replies_everyone_enabled")&.value&.starts_with?("t") || false
  old_settings_canned_replies_everyone_can_edit =
    SiteSetting.find_by(name: "canned_replies_everyone_can_edit")&.value&.starts_with?("t") || false

  category = nil

  I18n.with_locale(SiteSetting.default_locale) do
    category =
      Category.new(
        name: I18n.t("default_category_template.name")[0...50], # category names are limited to 50 chars in discourse
        description: I18n.t("default_category_template.description"),
        user: Discourse.system_user,
        all_topics_wiki: true,
      )
  end

  permissions = { staff: :full } # staff is always allowed to use and edit canned replies

  # get the existing groups and compares with the groups allowed to used canned replies
  # using the same algorithm that the plugin used to ensure that the same groups are authorized
  # if they are available
  groups = Group.all

  granted_group_list = old_settings_canned_replies_groups.split("|").map(&:downcase)

  groups
    .select { |group| granted_group_list.include?(group.name.downcase) }
    .each { |group| permissions.merge!({ group.name => :full }) }

  # insert privileges (or not) for everyone to use and edit canned replies
  # based on the two settings available
  if old_settings_canned_replies_everyone_enabled
    permissions.merge!(
      { everyone: old_settings_canned_replies_everyone_can_edit ? :full : :readonly },
    )
  end

  category.set_permissions(permissions)

  raise <<~ERROR unless category.save!
    ****************************
    ERROR while creating the existing_category to store the templates: #{category.errors.full_messages}

    If you can't fix the reason of the error, you can create a existing_category manually
    to store the templates and define it in Settings.discourse_templates_categories.

    Then proceed with this migration.
  ERROR

  puts "Created category #{category.name}(id: #{category.id}) to store the templates"

  category
end

def create_topic_from_v1_reply(reply, category)
  topic = Topic.new(title: reply[:title], user: Discourse.system_user, category_id: category.id)
  topic.custom_fields = { DiscourseTemplates::PLUGIN_NAME => reply[:id] }
  topic.skip_callbacks = true

  unless topic.save!(validate: false)
    raise "ERROR importing #{reply[:id]}: #{reply[:title]} - #{errors.full_messages}"
  end

  post = topic.posts.build(raw: reply[:content], user: Discourse.system_user, wiki: true)
  unless post.save!(validate: false)
    raise "ERROR importing #{reply[:id]}: #{reply[:title]} - #{errors.full_messages}"
  end

  usage_count =
    DiscourseTemplates::UsageCount.new(topic_id: topic.id, usage_count: reply[:usages] || 0)
  usage_count.save

  topic
end

def migrate_data_all_sites
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Starting DB: #{db} >>>>>>>>>>>>>>>>>>>>>>>>>"
    migrate_data
    puts "Ended DB: #{db} >>>>>>>>>>>>>>>>>>>>>>>>>"
  end
end

def migrate_data
  puts "Migrating data from discourse-canned-replies to discourse-templates"

  begin
    ActiveRecord::Base.transaction do
      category =
        if SiteSetting.discourse_templates_categories.blank?
          new_category = create_category
          SiteSetting.discourse_templates_categories = new_category.id.to_s

          new_category
        else
          existing_category =
            Category.find_by(id: SiteSetting.discourse_templates_categories&.split("|")&.first.to_i)

          if existing_category.blank?
            raise "Category specified not found. Check Settings.discourse_templates_categories"
          end

          puts "",
               "****************************",
               "Using existing category #{existing_category.name}(id: #{existing_category.id}) defined in Settings.discourse_templates_categories",
               "Please note that access to templates will follow this existing category security settings",
               "****************************",
               ""

          existing_category
        end

      canned_replies_plugin_name = "discourse-canned-replies"
      canned_replies_store_name = "replies"
      replies_v1 = PluginStore.get(canned_replies_plugin_name, canned_replies_store_name)

      count = replies_v1&.size || 0
      puts "no canned replies from v1 were located to be migrated to v2" if count == 0

      # duplicate topic titles must be temporarily enabled to ensure that all
      # canned replies can be imported since there is no guarantee that a previous
      # topic does not exist with the same title
      allow_duplicate_topic_titles = SiteSetting.allow_duplicate_topic_titles

      SiteSetting.allow_duplicate_topic_titles = true

      (replies_v1 || {}).each_with_index do |(_, reply), index|
        position = index + 1

        # search if a previous topic was already imported from this canned reply
        existing_topic =
          TopicCustomField.find_by(name: DiscourseTemplates::PLUGIN_NAME, value: reply[:id])

        if existing_topic.blank?
          topic = create_topic_from_v1_reply(reply, category)

          puts "[#{position}/#{count}] canned reply #{reply[:id]}: #{reply[:title]} imported to topic #{topic.id}"
        else
          puts "[#{position}/#{count}] skipping #{reply[:title]}. Topic previously imported found!"
        end
      end

      # restores the setting to the previous value after importing the topics
      SiteSetting.allow_duplicate_topic_titles = allow_duplicate_topic_titles
    end
    puts "", "Canned replies migration to templates finished!"
  rescue StandardError => e
    puts e
    puts "Transaction aborted! All changes were rolled back!"
  end
end

def purge_old_data_all_sites
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Starting DB: #{db} >>>>>>>>>>>>>>>>>>>>>>>>>"
    purge_old_data
    puts "Ended DB: #{db} >>>>>>>>>>>>>>>>>>>>>>>>>"
  end
end

def purge_old_data
  puts "Removing canned replies data"

  begin
    ActiveRecord::Base.transaction do
      DB.exec <<~SQL
        DELETE FROM site_settings#{" "}
        WHERE name IN (
          'canned_replies_groups',#{" "}
          'canned_replies_everyone_enabled',#{" "}
          'canned_replies_everyone_can_edit'
        )
      SQL

      canned_replies_plugin_name = "discourse-canned-replies"
      canned_replies_store_name = "replies"
      old_replies =
        PluginStoreRow.find_by(
          plugin_name: canned_replies_plugin_name,
          key: canned_replies_store_name,
        )

      old_replies.destroy! if old_replies.present?

      puts "Finished!"
    rescue StandardError => e
      puts e
      puts "Transaction aborted! All changes were rolled back!"
    end
  end
end
