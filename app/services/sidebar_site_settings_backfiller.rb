# frozen_string_literal: true

# A service class that backfills the changes to the default sidebar categories and tags site settings.
#
# When a category/tag is removed from the site settings, the `SidebarSectionLink` records associated with the category/tag
# are deleted.
#
# When a category/tag is added to the site settings, a `SidebarSectionLink` record for the associated category/tag are
# created for all users that do not already have a `SidebarSectionLink` record for the category/tag.
class SidebarSiteSettingsBackfiller
  def initialize(setting_name, previous_value:, new_value:)
    @setting_name = setting_name

    @linkable_klass, previous_ids, new_ids =
      case setting_name
      when "default_navigation_menu_categories"
        [Category, previous_value.split("|").map(&:to_i), new_value.split("|").map(&:to_i)]
      when "default_navigation_menu_tags"
        klass = Tag

        [
          klass,
          klass.where(name: previous_value.split("|")).pluck(:id),
          klass.where(name: new_value.split("|")).pluck(:id),
        ]
      else
        raise "Invalid setting_name"
      end

    @added_ids = new_ids - previous_ids
    @removed_ids = previous_ids - new_ids
  end

  # This should only be called from the `Jobs::BackfillSidebarSiteSettings` job as the job is ran with a cluster
  # concurrency of 1 to ensure that only one process is running the backfill at any point in time.
  def backfill!
    User
      .real
      .where(staged: false)
      .select(:id)
      .find_in_batches do |users|
        rows = []
        user_ids = users.map(&:id)

        user_ids.each do |user_id|
          @added_ids.each do |linkable_id|
            rows << {
              user_id: user_id,
              linkable_type: @linkable_klass.to_s,
              linkable_id: linkable_id,
            }
          end
        end

        SidebarSectionLink.transaction do
          SidebarSectionLink.where(
            user_id: user_ids,
            linkable_id: @removed_ids,
            linkable_type: @linkable_klass.to_s,
          ).delete_all

          SidebarSectionLink.insert_all(rows) if rows.present?
        end
      end
  end

  def number_of_users_to_backfill
    select_statements = []

    select_statements.push(<<~SQL) if @removed_ids.present?
      SELECT
        sidebar_section_links.user_id
      FROM sidebar_section_links
      WHERE sidebar_section_links.linkable_type = '#{@linkable_klass}'
      AND sidebar_section_links.linkable_id IN (#{@removed_ids.join(",")})
      SQL

    if @added_ids.present?
      # Returns the ids of users that will receive the new additions by excluding the users that already have the additions
      # Note that we want to avoid doing a left outer join against the "sidebar_section_links" table as PG will end up having
      # to do a full table join for both tables first which is less efficient and can be slow on large sites.
      select_statements.push(<<~SQL)
      SELECT
        users.id
      FROM users
      WHERE users.id NOT IN (
        SELECT
          DISTINCT(sidebar_section_links.user_id)
        FROM sidebar_section_links
        WHERE sidebar_section_links.linkable_type = '#{@linkable_klass}'
        AND sidebar_section_links.linkable_id IN (#{@added_ids.join(",")})
      ) AND users.id > 0 AND NOT users.staged
      SQL
    end

    return 0 if select_statements.blank?

    DB.query_single(<<~SQL)[0]
    SELECT
      COUNT(*)
    FROM (#{select_statements.join("\nUNION DISTINCT\n")}) AS user_ids
    SQL
  end
end
