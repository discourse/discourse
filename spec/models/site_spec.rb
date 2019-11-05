# frozen_string_literal: true

require 'rails_helper'

describe Site do

  def expect_correct_themes(guardian)
    json = Site.json_for(guardian)
    parsed = JSON.parse(json)

    expected = Theme.where('id = :default OR user_selectable',
                    default: SiteSetting.default_theme_id)
      .order(:name)
      .pluck(:id, :name)
      .map { |id, n| { "theme_id" => id, "name" => n, "default" => id == SiteSetting.default_theme_id } }

    expect(parsed["user_themes"]).to eq(expected)
  end

  it "includes user themes and expires them as needed" do
    default_theme = Fabricate(:theme)
    SiteSetting.default_theme_id = default_theme.id
    user_theme = Fabricate(:theme, user_selectable: true)

    anon_guardian = Guardian.new
    user_guardian = Guardian.new(Fabricate(:user))

    expect_correct_themes(anon_guardian)
    expect_correct_themes(user_guardian)

    Theme.clear_default!

    expect_correct_themes(anon_guardian)
    expect_correct_themes(user_guardian)

    user_theme.user_selectable = false
    user_theme.save!

    expect_correct_themes(anon_guardian)
    expect_correct_themes(user_guardian)

  end

  it "returns correct notification level for categories" do
    category = Fabricate(:category)
    guardian = Guardian.new
    expect(Site.new(guardian).categories.last.notification_level).to eq(1)
    SiteSetting.mute_all_categories_by_default = true
    expect(Site.new(guardian).categories.last.notification_level).to eq(0)
    SiteSetting.default_categories_tracking = category.id.to_s
    expect(Site.new(guardian).categories.last.notification_level).to eq(1)
  end

  it "omits categories users can not write to from the category list" do
    category = Fabricate(:category)
    user = Fabricate(:user)

    expect(Site.new(Guardian.new(user)).categories.count).to eq(2)

    category.set_permissions(everyone: :create_post)
    category.save

    guardian = Guardian.new(user)

    expect(Site.new(guardian)
        .categories
        .keep_if { |c| c.name == category.name }
        .first
        .permission)
      .not_to eq(CategoryGroup.permission_types[:full])

    # If a parent category is not visible, the child categories should not be returned
    category.set_permissions(staff: :full)
    category.save

    sub_category = Fabricate(:category, parent_category_id: category.id)
    expect(Site.new(guardian).categories).not_to include(sub_category)
  end

  it "omits groups user can not see" do
    user = Fabricate(:user)
    site = Site.new(Guardian.new(user))

    staff_group = Fabricate(:group, visibility_level: Group.visibility_levels[:staff])
    expect(site.groups.pluck(:name)).not_to include(staff_group.name)

    public_group = Fabricate(:group)
    expect(site.groups.pluck(:name)).to include(public_group.name)

    admin = Fabricate(:admin)
    site = Site.new(Guardian.new(admin))
    expect(site.groups.pluck(:name)).to include(staff_group.name, public_group.name, "everyone")
  end

  it "includes all enabled authentication providers" do
    SiteSetting.enable_twitter_logins = true
    SiteSetting.enable_facebook_logins = true
    data = JSON.parse(Site.json_for(Guardian.new))
    expect(data["auth_providers"].map { |a| a["name"] }).to contain_exactly('facebook', 'twitter')
  end

  it "includes all enabled authentication providers for anon when login_required" do
    SiteSetting.login_required = true
    SiteSetting.enable_twitter_logins = true
    SiteSetting.enable_facebook_logins = true
    data = JSON.parse(Site.json_for(Guardian.new))
    expect(data["auth_providers"].map { |a| a["name"] }).to contain_exactly('facebook', 'twitter')
  end

end
