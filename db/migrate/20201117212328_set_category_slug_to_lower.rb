# frozen_string_literal: true

class SetCategorySlugToLower < ActiveRecord::Migration[6.0]
  def up
    remove_index(:categories, name: "unique_index_categories_on_slug")

    categories = DB.query("SELECT id, name, slug, parent_category_id FROM categories")
    old_slugs = categories.map { |c| [c.id, c.slug] }.to_h
    updates = {}

    # Resolve duplicate tags by replacing mixed case slugs with new ones
    # extracted from category names
    slugs =
      categories
        .filter { |category| category.slug.present? }
        .group_by { |category| [category.parent_category_id, category.slug.downcase] }
        .map { |slug, cats| [slug, cats.size] }
        .to_h

    categories.each do |category|
      old_parent_and_slug = [category.parent_category_id, category.slug.downcase]
      if category.slug.blank? || category.slug == category.slug.downcase ||
           slugs[old_parent_and_slug] <= 1
        next
      end

      new_slug = category.name.parameterize.tr("_", "-").squeeze("-").gsub(/\A-+|-+\z/, "")[0..255]
      new_slug = "" if (new_slug =~ /[^\d]/).blank?
      new_parent_and_slug = [category.parent_category_id, new_slug]
      if new_slug.blank? || (slugs[new_parent_and_slug].present? && slugs[new_parent_and_slug] > 0)
        next
      end

      updates[category.id] = category.slug = new_slug
      slugs[old_parent_and_slug] -= 1
      slugs[new_parent_and_slug] = 1
    end

    # Reset left conflicting slugs
    slugs =
      categories
        .filter { |category| category.slug.present? }
        .group_by { |category| [category.parent_category_id, category.slug.downcase] }
        .map { |slug, cats| [slug, cats.size] }
        .to_h

    categories.each do |category|
      old_parent_and_slug = [category.parent_category_id, category.slug.downcase]
      if category.slug.blank? || category.slug == category.slug.downcase ||
           slugs[old_parent_and_slug] <= 1
        next
      end

      updates[category.id] = category.slug = ""
      slugs[old_parent_and_slug] -= 1
    end

    # Update all category slugs
    updates.each { |id, slug| execute <<~SQL }
        UPDATE categories
        SET slug = '#{PG::Connection.escape_string(slug)}'
        WHERE id = #{id} -- #{PG::Connection.escape_string(old_slugs[id])}
      SQL

    # Ensure all slugs are lowercase
    execute "UPDATE categories SET slug = LOWER(slug)"

    add_index(
      :categories,
      "COALESCE(parent_category_id, -1), LOWER(slug)",
      name: "unique_index_categories_on_slug",
      where: "slug != ''",
      unique: true,
    )
  end

  def down
    remove_index(:categories, name: "unique_index_categories_on_slug")

    add_index(
      :categories,
      "COALESCE(parent_category_id, -1), slug",
      name: "unique_index_categories_on_slug",
      where: "slug != ''",
      unique: true,
    )
  end
end
