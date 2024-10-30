# frozen_string_literal: true

class AboutSerializer < ApplicationSerializer
  class CategoryAboutSerializer < CategoryBadgeSerializer
    has_one :parent_category, serializer: CategoryBadgeSerializer, root: :categories
  end

  class UserAboutSerializer < BasicUserSerializer
    attributes :title, :last_seen_at
  end

  class AboutCategoryModsSerializer < ApplicationSerializer
    has_one :category, serializer: CategoryAboutSerializer
    has_many :moderators, serializer: UserAboutSerializer, root: :users
  end

  has_many :moderators, serializer: UserAboutSerializer, root: :users
  has_many :admins, serializer: UserAboutSerializer, root: :users
  has_many :category_moderators, serializer: AboutCategoryModsSerializer, embed: :objects

  attributes :stats,
             :description,
             :extended_site_description,
             :banner_image,
             :site_creation_date,
             :title,
             :locale,
             :version,
             :https,
             :can_see_about_stats,
             :contact_url,
             :contact_email

  def include_stats?
    can_see_about_stats
  end

  def stats
    object.class.fetch_cached_stats
  end

  def include_contact_url?
    can_see_site_contact_details
  end

  def contact_url
    SiteSetting.contact_url
  end

  def include_contact_email?
    can_see_site_contact_details
  end

  def contact_email
    SiteSetting.contact_email
  end

  private

  def can_see_about_stats
    scope.can_see_about_stats?
  end

  def can_see_site_contact_details
    scope.can_see_site_contact_details?
  end
end
