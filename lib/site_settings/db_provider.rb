# frozen_string_literal: true

module SiteSettings; end

class SiteSettings::DbProvider

  def initialize(model)
    model.after_commit do
      model.notify_changed!
    end

    @model = model
  end

  def all
    return [] if !database_and_table_exists?

    # Not leaking out AR records, cause I want all editing to happen via this API
    DB.query("SELECT name, data_type, value FROM #{@model.table_name}")
  end

  def find(name)
    return nil if !database_and_table_exists?

    # Not leaking out AR records, cause I want all editing to happen via this API
    DB.query("SELECT name, data_type, value FROM #{@model.table_name} WHERE name = ?", name)
      .first
  end

  def save(name, value, data_type)
    return if !database_and_table_exists?

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
    return if !database_and_table_exists?

    @model.where(name: name).destroy_all
  end

  def current_site
    RailsMultisite::ConnectionManagement.current_db
  end

  protected

  def database_and_table_exists?
    database_exists? && table_exists?
  end

  def database_exists?
    ActiveRecord::Base.connection
  rescue ActiveRecord::NoDatabaseError
    false
  end

  # table is not in the db yet, initial migration, etc
  def table_exists?
    @table_exists ||= {}
    @table_exists[current_site] ||= ActiveRecord::Base.connection.table_exists?(@model.table_name)
  end

end
