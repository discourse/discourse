# frozen_string_literal: true

class AddInvitesLinkToSidebar < ActiveRecord::Migration[7.1]
  def up
    community_section_id = DB.query_single(<<~SQL).first
      SELECT id
      FROM sidebar_sections
      WHERE section_type = 0
    SQL

    return if !community_section_id

    existing_links = DB.query(<<~SQL, section_id: community_section_id).sort_by(&:position)
      SELECT su.*, position, ssl.id AS ssl_id
      FROM sidebar_urls su
      INNER JOIN sidebar_section_links ssl
      ON su.id = ssl.linkable_id
      AND ssl.linkable_type = 'SidebarUrl'
      AND ssl.sidebar_section_id = :section_id
    SQL

    DB.exec(<<~SQL, ids: existing_links.map(&:id))
      DELETE FROM sidebar_urls
      WHERE id IN (:ids)
    SQL
    DB.exec(<<~SQL, ids: existing_links.map(&:ssl_id))
      DELETE FROM sidebar_section_links
      WHERE id IN (:ids)
    SQL

    primary_links =
      existing_links
        .select { |link| link.segment == 0 }
        .map do |link|
          {
            name: link.name,
            value: link.value,
            icon: link.icon,
            external: link.external,
            segment: 0,
            created_at: link.created_at,
            updated_at: link.updated_at,
          }
        end

    secondary_links =
      existing_links
        .select { |link| link.segment == 1 }
        .map do |link|
          {
            name: link.name,
            value: link.value,
            icon: link.icon,
            external: link.external,
            segment: 1,
            created_at: link.created_at,
            updated_at: link.updated_at,
          }
        end

    primary_links << {
      name: "Invite members",
      value: "/new-invite",
      icon: "paper-plane",
      external: false,
      segment: 0,
      created_at: Time.zone.now,
      updated_at: Time.zone.now,
    }

    position = 0
    new_links = []
    [primary_links, secondary_links].each do |links|
      links.each do |link|
        id = DB.query_single(<<~SQL, **link).first
          INSERT INTO sidebar_urls
          (name, value, icon, external, segment, created_at, updated_at)
          VALUES
          (:name, :value, :icon, :external, :segment, :created_at, :updated_at)
          RETURNING sidebar_urls.id
        SQL

        DB.exec(
          <<~SQL,
          INSERT INTO sidebar_section_links
          (user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
          VALUES
          (-1, :linkable_id, 'SidebarUrl', :section_id, :position, :created_at, :updated_at)
        SQL
          linkable_id: id,
          section_id: community_section_id,
          position:,
          created_at: link[:created_at],
          updated_at: link[:updated_at],
        )
        position += 1
      end
    end
  end

  def down
  end
end
