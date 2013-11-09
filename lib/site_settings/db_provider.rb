module SiteSettings; end

class SiteSettings::DbProvider

  def initialize(model)
    @model = model
  end

  def all
    return [] unless table_exists?

    # note, not leaking out AR records, cause I want all editing to happen
    # via this API
    SqlBuilder.new("select name, data_type, value from #{@model.table_name}").map_exec(OpenStruct)
  end

  def find(name)
    return nil unless table_exists?

    # note, not leaking out AR records, cause I want all editing to happen
    # via this API
    SqlBuilder.new("select name, data_type, value from #{@model.table_name} where name = :name")
      .map_exec(OpenStruct, name: name)
      .first
  end

  def save(name, value, data_type)

    return unless table_exists?

    count = @model.where({
      name: name
    }).update_all({
      name: name,
      value: value,
      data_type: data_type,
      updated_at: Time.now
    })

    if count == 0
      @model.create!(name: name, value: value, data_type: data_type)
    end

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
    @table_exists = ActiveRecord::Base.connection.table_exists? @model.table_name unless @table_exists
    @table_exists
  end

end
