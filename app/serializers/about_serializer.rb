# frozen_string_literal: true

class AboutSerializer < ApplicationSerializer

  class UserAboutSerializer < BasicUserSerializer
    attributes :title, :last_seen_at
  end

  class AboutCategoryModsSerializer < ApplicationSerializer
    attributes :category_id

    has_many :moderators, serializer: UserAboutSerializer, embed: :objects
  end

  has_many :moderators, serializer: UserAboutSerializer, embed: :objects
  has_many :admins, serializer: UserAboutSerializer, embed: :objects
  has_many :category_moderators, serializer: AboutCategoryModsSerializer, embed: :objects

  attributes :stats,
             :description,
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
    object.class.fetch_cached_stats || Jobs::AboutStats.new.execute({})
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
