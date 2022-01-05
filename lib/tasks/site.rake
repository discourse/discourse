# frozen_string_literal: true

require 'yaml'
require 'zip'

class ZippedSiteStructure
  attr_reader :zip

  def initialize(path, create: false)
    @zip = Zip::File.open(path, create)
    @uploads = {}
  end

  def close
    @zip.close
  end

  def set(name, data)
    @zip.get_output_stream("#{name}.json") do |file|
      file.write(data.to_json)
    end
  end

  def get(name)
    data = @zip.get_input_stream("#{name}.json").read
    JSON.parse(data)
  end

  def set_upload(upload_or_id_or_url)
    return nil if upload_or_id_or_url.blank?

    if Integer === upload_or_id_or_url
      upload = Upload.find_by(id: upload_or_id_or_url)
    elsif String === upload_or_id_or_url
      upload = Upload.get_from_url(upload_or_id_or_url)
    elsif Upload === upload_or_id_or_url
      upload = upload_or_id_or_url
    end

    if !upload
      STDERR.puts "ERROR: Could not find upload #{upload_or_id_or_url.inspect}"
      return nil
    end

    if @uploads[upload.id].present?
      puts "  - Already exported upload #{upload_or_id_or_url} to #{@uploads[upload.id][:path]}"
      return @uploads[upload.id]
    end

    local_path = upload.local? ? Discourse.store.path_for(upload) : Discourse.store.download(upload).path
    zip_path = File.join('uploads', File.basename(local_path))
    zip_path = get_unique_path(zip_path)

    puts "  - Exporting upload #{upload_or_id_or_url} to #{zip_path}"
    @zip.add(zip_path, local_path)

    @uploads[upload.id] ||= { filename: upload.original_filename, path: zip_path }
  end

  def get_upload(upload, opts = {})
    return nil if upload.blank?

    if @uploads[upload['path']].present?
      puts "  - Already imported upload #{upload['filename']} from #{upload['path']}"
      return @uploads[upload['path']]
    end

    puts "  - Importing upload #{upload['filename']} from #{upload['path']}"

    tempfile = Tempfile.new(upload['filename'], binmode: true)
    tempfile.write(@zip.get_input_stream(upload['path']).read)
    tempfile.rewind

    @uploads[upload['path']] ||= UploadCreator.new(tempfile, upload['filename'], opts).create_for(Discourse::SYSTEM_USER_ID)
  end

  private

  def get_unique_path(path)
    return path if @zip.find_entry(path).blank?

    extname = File.extname(path)
    basename = File.basename(path, extname)
    dirname = File.dirname(path)

    i = 0
    loop do
      i += 1
      path = File.join(dirname, "#{basename}_#{i}#{extname}")
      return path if @zip.find_entry(path).blank?
    end
  end
end

desc 'Exports site structure (settings, groups, categories, tags, themes, etc) to a ZIP file'
task 'site:export_structure', [:zip_path] => :environment do |task, args|
  if args[:zip_path].blank?
    STDERR.puts "ERROR: rake site:export_structure[<path to ZIP file>]"
    exit 1
  elsif File.exist?(args[:zip_path])
    STDERR.puts "ERROR: File '#{args[:zip_path]}' already exists"
    exit 2
  end

  data = ZippedSiteStructure.new(args[:zip_path], create: true)

  puts
  puts "Exporting site settings"
  puts

  settings = {}

  SiteSetting.all_settings(include_hidden: true).each do |site_setting|
    next if site_setting[:default] == site_setting[:value]

    puts "- Site setting #{site_setting[:setting]} -> #{site_setting[:value].inspect}"

    settings[site_setting[:setting]] = if site_setting[:type] == 'upload'
      data.set_upload(site_setting[:value])
    else
      site_setting[:value]
    end
  end

  data.set('site_settings', settings)

  puts
  puts "Exporting users"
  puts

  users = []

  User.real.where(admin: true).each do |u|
    puts "- User #{u.username}"

    users << {
      username: u.username,
      name: u.name,
      email: u.email,
      active: u.active,
      admin: u.admin,
    }
  end

  data.set('users', users)

  puts
  puts "Exporting groups"
  puts

  groups = []

  Group.where(automatic: false).each do |g|
    puts "- Group #{g.name}"

    groups << {
      name: g.name,
      automatic_membership_email_domains: g.automatic_membership_email_domains,
      primary_group: g.primary_group,
      title: g.title,
      grant_trust_level: g.grant_trust_level,
      incoming_email: g.incoming_email,
      has_messages: g.has_messages,
      flair_bg_color: g.flair_bg_color,
      flair_color: g.flair_color,
      bio_raw: g.bio_raw,
      allow_membership_requests: g.allow_membership_requests,
      full_name: g.full_name,
      default_notification_level: g.default_notification_level,
      visibility_level: g.visibility_level,
      public_exit: g.public_exit,
      public_admission: g.public_admission,
      membership_request_template: g.membership_request_template,
      messageable_level: g.messageable_level,
      mentionable_level: g.mentionable_level,
      publish_read_state: g.publish_read_state,
      members_visibility_level: g.members_visibility_level,
      flair_icon: g.flair_icon,
      flair_upload_id: data.set_upload(g.flair_upload_id),
      allow_unknown_sender_topic_replies: g.allow_unknown_sender_topic_replies,
    }
  end

  data.set('groups', groups)

  puts
  puts "Exporting categories"
  puts

  categories = []

  Category.find_each do |c|
    puts "- Category #{c.name} (#{c.slug})"

    categories << {
      name: c.name,
      color: c.color,
      slug: c.slug,
      description: c.description,
      text_color: c.text_color,
      read_restricted: c.read_restricted,
      auto_close_hours: c.auto_close_hours,
      parent_category: c.parent_category&.slug,
      position: c.position,
      email_in: c.email_in,
      email_in_allow_strangers: c.email_in_allow_strangers,
      allow_badges: c.allow_badges,
      auto_close_based_on_last_post: c.auto_close_based_on_last_post,
      topic_template: c.topic_template,
      sort_order: c.sort_order,
      sort_ascending: c.sort_ascending,
      uploaded_logo_id: data.set_upload(c.uploaded_logo_id),
      uploaded_background_id: data.set_upload(c.uploaded_background_id),
      topic_featured_link_allowed: c.topic_featured_link_allowed,
      all_topics_wiki: c.all_topics_wiki,
      show_subcategory_list: c.show_subcategory_list,
      default_view: c.default_view,
      subcategory_list_style: c.subcategory_list_style,
      default_top_period: c.default_top_period,
      mailinglist_mirror: c.mailinglist_mirror,
      minimum_required_tags: c.minimum_required_tags,
      navigate_to_first_post_after_read: c.navigate_to_first_post_after_read,
      search_priority: c.search_priority,
      allow_global_tags: c.allow_global_tags,
      read_only_banner: c.read_only_banner,
      default_list_filter: c.default_list_filter,
      permissions: c.permissions_params,
    }
  end

  data.set('categories', categories)

  puts
  puts "Exporting tag groups"
  puts

  tag_groups = []

  TagGroup.all.each do |tg|
    puts "- Tag group #{tg.name}"

    tag_groups << {
      name: tg.name,
      tag_names: tg.tags.map(&:name)
    }
  end

  data.set('tag_groups', tag_groups)

  puts
  puts "Exporting tags"
  puts

  tags = []

  Tag.find_each do |t|
    puts "- Tag #{t.name}"

    tag = { name: t.name }
    tag[:target_tag] = t.target_tag.name if t.target_tag.present?

    tags << tag
  end

  data.set('tags', tags)

  puts
  puts "Exporting themes and theme components"
  puts

  themes = []

  Theme.find_each do |theme|
    puts "- Theme #{theme.name}"

    if theme.remote_theme.present?
      themes << {
        name: theme.name,
        url: theme.remote_theme.remote_url,
        private_key: theme.remote_theme.private_key,
        branch: theme.remote_theme.branch
      }
    else
      exporter = ThemeStore::ZipExporter.new(theme)
      file_path = exporter.package_filename
      file_zip_path = File.join('themes', File.basename(file_path))
      data.zip.add(file_zip_path, file_path)
      themes << { name: theme.name, filename: File.basename(file_path), path: file_zip_path }
    end
  end

  data.set('themes', themes)

  puts
  puts "Exporting theme settings"
  puts

  theme_settings = []

  ThemeSetting.find_each do |theme_setting|
    puts "- Theme setting #{theme_setting.name} -> #{theme_setting.value}"

    value = if theme_setting.data_type == ThemeSetting.types[:upload]
      data.set_upload(theme_setting.value)
    else
      theme_setting.value
    end

    theme_settings << {
      name: theme_setting.name,
      data_type: theme_setting.data_type,
      value: value,
      theme: theme_setting.theme.name,
    }
  end

  data.set('theme_settings', theme_settings)

  puts
  puts "Done"
  puts

  data.close
end

desc 'Imports site structure from a ZIP file exported by site:export_structure'
task 'site:import_structure', [:zip_path] => :environment do |task, args|
  if args[:zip_path].blank?
    STDERR.puts "ERROR: rake site:import_structure[<path to ZIP file>]"
    exit 1
  elsif !File.exist?(args[:zip_path])
    STDERR.puts "ERROR: File '#{args[:zip_path]}' does not exist"
    exit 2
  end

  data = ZippedSiteStructure.new(args[:zip_path])

  puts
  puts "Importing site settings"
  puts

  settings = data.get('site_settings')
  imported_settings = Set.new

  3.times.each do |try|
    puts "Loading site settings (try ##{try})"

    settings.each do |key, value|
      next if imported_settings.include?(key)

      begin
        if SiteSetting.type_supervisor.get_type(key) == :upload
          value = data.get_upload(value, for_site_setting: true)
        end

        if SiteSetting.public_send(key) != value
          puts "- Site setting #{key} -> #{value}"
          SiteSetting.set_and_log(key, value)
        end

        imported_settings << key
      rescue => e
        next if try < 2

        STDERR.puts "ERROR: Cannot set #{key} to #{value}"
        puts e.backtrace
      end
    end
  end

  puts
  puts "Importing users"
  puts

  data.get('users').each do |u|
    puts "- User #{u['username']}"

    begin
      user = User.find_or_initialize_by(username: u.delete('username'))
      user.update!(u)
    rescue => e
      STDERR.puts "ERROR: Cannot import user: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Importing groups"
  puts

  data.get('groups').each do |g|
    puts "- Group #{g['name']}"

    begin
      group = Group.find_or_initialize_by(name: g.delete('name'))
      group.update!(g)
    rescue => e
      STDERR.puts "ERROR: Cannot import group: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Importing categories"
  puts

  data.get('categories').each do |c|
    puts "- Category #{c['name']} (#{c['slug']})"

    begin
      category = Category.find_or_initialize_by(slug: c.delete('slug'))
      category.user ||= Discourse.system_user
      category.parent_category = Category.find_by(slug: c.delete('parent_category'))
      category.permissions = c.delete('permissions')
      category.update!(c)
    rescue => e
      STDERR.puts "ERROR: Cannot import category: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Importing tag groups"
  puts

  data.get('tag_groups').each do |tg|
    puts "- Tag group #{tg['name']}"

    tag_group = TagGroup.find_or_initialize_by(name: tg.delete('name'))
    tag_group.update!(tg)
  end

  puts
  puts "Importing tags"
  puts

  data.get('tags').each do |t|
    puts "- Tag #{t['name']}"

    if t['target_tag'].present?
      begin
        t['target_tag'] = Tag.find_or_create_by!(name: t.delete('target_tag'))
      rescue => e
        STDERR.puts "ERROR: Cannot import target tag: #{e.message}"
        puts e.backtrace
      end
    end

    begin
      tag = Tag.find_or_initialize_by(name: t.delete('name'))
      tag.update!(t)
    rescue => e
      STDERR.puts "ERROR: Cannot import tag: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Importing themes and theme components"
  puts

  data.get('themes').each do |t|
    puts "- Theme #{t['name']}"

    begin
      if t['url'].present?
        next if Theme.find_by(name: t['name']).present?

        RemoteTheme.import_theme(
          t['url'],
          Discourse.system_user,
          private_key: t['private_key'],
          branch: t['branch']
        )
      elsif t['filename'].present?
        tempfile = Tempfile.new(t['filename'], binmode: true)
        tempfile.write(data.zip.get_input_stream(t['path']).read)
        tempfile.flush

        RemoteTheme.update_zipped_theme(
          tempfile.path,
          t['filename'],
          user: Discourse.system_user,
          theme_id: Theme.find_by(name: t['name'])&.id,
        )
      end
    rescue => e
      STDERR.puts "ERROR: Cannot import theme: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Importing theme settings"
  puts

  data.get('theme_settings').each do |ts|
    puts "- Theme setting #{ts['name']} -> #{ts['value']}"

    begin
      if ts['data_type'] == ThemeSetting.types[:upload]
        ts['value'] = data.get_upload(ts['value'], for_theme: true)
      end

      ThemeSetting
        .find_or_initialize_by(name: ts['name'], theme: Theme.find_by(name: ts['theme']))
        .update!(data_type: ts['data_type'], value: ts['value'])
    rescue => e
      STDERR.puts "ERROR: Cannot import theme setting: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Done"
  puts

  data.close
end
