# frozen_string_literal: true

class SidebarSectionLinksUpdater
  def self.update_category_section_links(user, category_ids:)
    if category_ids.blank?
      delete_section_links(user: user, linkable_type: "Category")
    else
      category_ids = Category.secured(Guardian.new(user)).where(id: category_ids).pluck(:id)
      update_section_links(user: user, linkable_type: "Category", new_linkable_ids: category_ids)
    end
  end

  def self.update_tag_section_links(user, tag_names:)
    if tag_names.blank?
      delete_section_links(user: user, linkable_type: "Tag")
    else
      tag_ids =
        DiscourseTagging.filter_visible(Tag, Guardian.new(user)).where(name: tag_names).pluck(:id)

      update_section_links(user: user, linkable_type: "Tag", new_linkable_ids: tag_ids)
    end
  end

  def self.delete_section_links(user:, linkable_type:)
    SidebarSectionLink.where(user: user, linkable_type: linkable_type).delete_all
  end
  private_class_method :delete_section_links

  def self.update_section_links(user:, linkable_type:, new_linkable_ids:)
    SidebarSectionLink.transaction do
      existing_linkable_ids =
        SidebarSectionLink.where(user: user, linkable_type: linkable_type).pluck(:linkable_id)

      to_delete = existing_linkable_ids - new_linkable_ids
      to_insert = new_linkable_ids - existing_linkable_ids

      to_insert_attributes =
        to_insert.map do |linkable_id|
          { linkable_type: linkable_type, linkable_id: linkable_id, user_id: user.id }
        end

      if to_delete.present?
        SidebarSectionLink.where(
          user: user,
          linkable_type: linkable_type,
          linkable_id: to_delete,
        ).delete_all
      end
      SidebarSectionLink.insert_all(to_insert_attributes) if to_insert_attributes.present?
    end
  end
  private_class_method :update_section_links
end
