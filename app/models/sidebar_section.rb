# frozen_string_literal: true

class SidebarSection < ActiveRecord::Base
  MAX_TITLE_LENGTH = 30
  MAX_USER_CATEGORY_LINKS = 100

  belongs_to :user
  has_many :sidebar_section_links, -> { order("position") }, dependent: :destroy

  has_many :sidebar_urls,
           through: :sidebar_section_links,
           source: :linkable,
           source_type: "SidebarUrl"

  accepts_nested_attributes_for :sidebar_urls,
                                allow_destroy: true,
                                limit: -> { SiteSetting.max_sidebar_section_links }

  before_save :set_system_user_for_public_section

  validates :title,
            presence: true,
            uniqueness: {
              scope: %i[user_id],
            },
            length: {
              maximum: MAX_TITLE_LENGTH,
            }

  scope :public_sections, -> { where("public") }
  enum :section_type, { community: 0 }, scopes: false, suffix: true

  def reset_community!
    ActiveRecord::Base.transaction do
      self.update!(title: "Community")
      self.sidebar_section_links.destroy_all
      community_urls =
        SidebarUrl::COMMUNITY_SECTION_LINKS.map do |url_data|
          "('#{url_data[:name]}', '#{url_data[:path]}', '#{url_data[:icon]}', '#{url_data[:segment]}', false, now(), now())"
        end

      result = DB.query <<~SQL
      INSERT INTO sidebar_urls(name, value, icon, segment, external, created_at, updated_at)
      VALUES #{community_urls.join(",")}
      RETURNING sidebar_urls.id
      SQL

      sidebar_section_links =
        result.map.with_index do |url, index|
          "(-1, #{url.id}, 'SidebarUrl', #{self.id}, #{index},  now(), now())"
        end

      DB.query <<~SQL
      INSERT INTO sidebar_section_links(user_id, linkable_id, linkable_type, sidebar_section_id, position, created_at, updated_at)
      VALUES #{sidebar_section_links.join(",")}
      SQL
    end
  end

  private

  def set_system_user_for_public_section
    self.user_id = Discourse.system_user.id if self.public
  end
end

# == Schema Information
#
# Table name: sidebar_sections
#
#  id           :bigint           not null, primary key
#  user_id      :integer          not null
#  title        :string(30)       not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public       :boolean          default(FALSE), not null
#  section_type :integer
#
# Indexes
#
#  index_sidebar_sections_on_section_type       (section_type) UNIQUE
#  index_sidebar_sections_on_user_id_and_title  (user_id,title) UNIQUE
#
