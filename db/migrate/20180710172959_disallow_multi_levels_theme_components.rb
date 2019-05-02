# frozen_string_literal: true

class DisallowMultiLevelsThemeComponents < ActiveRecord::Migration[5.2]
  def up
    @handled = []
    top_parents = DB.query("
      SELECT parent_theme_id, child_theme_id
      FROM child_themes
      WHERE parent_theme_id NOT IN (SELECT child_theme_id FROM child_themes)
    ")

    top_parents.each do |top_parent|
      migrate_child(top_parent, top_parent)
    end

    if @handled.size > 0
      execute("
        DELETE FROM child_themes
        WHERE parent_theme_id NOT IN (#{top_parents.map(&:parent_theme_id).join(", ")})
      ")
    end

    execute("
      UPDATE themes
      SET user_selectable = false
      FROM child_themes
      WHERE themes.id = child_themes.child_theme_id
      AND themes.user_selectable = true
    ")

    default = DB.query_single("SELECT value FROM site_settings WHERE name = 'default_theme_id'").first
    if default
      default_child = DB.query("SELECT 1 AS one FROM child_themes WHERE child_theme_id = ?", default.to_i).present?
      execute("DELETE FROM site_settings WHERE name = 'default_theme_id'") if default_child
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_child(parent, top_parent)
    unless already_exists?(top_parent.parent_theme_id, parent.child_theme_id)
      execute("
        INSERT INTO child_themes (parent_theme_id, child_theme_id, created_at, updated_at)
        VALUES (#{top_parent.parent_theme_id}, #{parent.child_theme_id}, now(), now())
      ")
    end

    @handled << [top_parent.parent_theme_id, parent.parent_theme_id, parent.child_theme_id]

    children = DB.query("
      SELECT parent_theme_id, child_theme_id
      FROM child_themes
      WHERE parent_theme_id = :child", child: parent.child_theme_id
    )

    children.each do |child|
      unless @handled.include?([top_parent.parent_theme_id, child.parent_theme_id, child.child_theme_id])
        migrate_child(child, top_parent)
      end
    end
  end

  def already_exists?(parent, child)
    DB.query("SELECT 1 AS one FROM child_themes WHERE child_theme_id = :child AND parent_theme_id = :parent", child: child, parent: parent).present?
  end
end
