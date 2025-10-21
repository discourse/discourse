# frozen_string_literal: true

module SiteSettings
end

class SiteSettings::DbProvider
  def initialize(model)
    model.after_commit { model.notify_changed! }

    @model = model
  end

  def all
    return [] unless table_exists?

    # Not leaking out AR records, cause I want all editing to happen via this API
    DB.query("SELECT name, data_type, value FROM #{@model.table_name}")
  end

  def find(name)
    return nil unless table_exists?

    # Not leaking out AR records, cause I want all editing to happen via this API
    DB.query("SELECT name, data_type, value FROM #{@model.table_name} WHERE name = ?", name).first
  end

  def save(name, value, data_type)
    return unless table_exists?

    model = @model.find_by(name: name)
    model ||= @model.new

    model.name = name
    model.value = value
    model.data_type = data_type

    # save! used to ensure after_commit is called
    model.save! if model.changed?

    true
  end

  def destroy(name)
    return unless table_exists?

    @model.where(name: name).destroy_all
  end

  def current_site
    RailsMultisite::ConnectionManagement.current_db
  end

  protected

  # table is not in the db yet, initial migration, etc
  def table_exists?
    @table_exists ||= {}
    @table_exists[current_site] ||= ActiveRecord::Base.connection.table_exists?(@model.table_name)
  end

  def site_setting_groups_table_exists?
    @site_setting_groups_table_exists ||= {}
    @site_setting_groups_table_exists[current_site] ||= ActiveRecord::Base.connection.table_exists?(
      "site_setting_groups",
    )
  end
end
