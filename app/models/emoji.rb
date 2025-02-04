# frozen_string_literal: true

class Emoji
  # update this to clear the cache
  EMOJI_VERSION = "12"

  FITZPATRICK_SCALE = %w[1f3fb 1f3fc 1f3fd 1f3fe 1f3ff]

  DEFAULT_GROUP = "default"

  include ActiveModel::SerializerSupport

  attr_accessor :name, :url, :tonable, :group, :search_aliases, :created_by

  def self.global_emoji_cache
    @global_emoji_cache ||= DistributedCache.new("global_emoji_cache", namespace: false)
  end

  def self.site_emoji_cache
    @site_emoji_cache ||= DistributedCache.new("site_emoji_cache")
  end

  def self.all
    Discourse.cache.fetch(cache_key("all_emojis")) { standard | custom }
  end

  def self.standard
    Discourse.cache.fetch(cache_key("standard_emojis")) { load_standard }
  end

  def self.allowed
    Discourse.cache.fetch(cache_key("allowed_emojis")) { load_allowed }
  end

  def self.denied
    Discourse.cache.fetch(cache_key("denied_emojis")) { load_denied }
  end

  def self.aliases
    db["aliases"]
  end

  def self.search_aliases
    db["searchAliases"]
  end

  def self.translations
    Discourse.cache.fetch(cache_key("translations_emojis")) { load_translations }
  end

  def self.custom
    Discourse.cache.fetch(cache_key("custom_emojis")) { load_custom }
  end

  def self.tonable_emojis
    db["tonableEmojis"]
  end

  def self.custom?(name)
    name = name.delete_prefix(":").delete_suffix(":")
    Emoji.custom.detect { |e| e.name == name }.present?
  end

  def self.exists?(name)
    Emoji[name].present?
  end

  def self.[](name)
    name = name.delete_prefix(":").delete_suffix(":")
    is_toned = name.match?(/\A.+:t[1-6]\z/)
    normalized_name = name.gsub(/\A(.+):t[1-6]\z/, '\1')

    found_emoji = nil

    [[global_emoji_cache, :standard], [site_emoji_cache, :custom]].each do |cache, list_key|
      found_emoji =
        cache.defer_get_set(normalized_name) do
          [
            Emoji
              .public_send(list_key)
              .detect { |e| e.name == normalized_name && (!is_toned || (is_toned && e.tonable)) },
          ]
        end[
          0
        ]

      break if found_emoji
    end

    found_emoji
  end

  def self.create_from_db_item(emoji)
    name = emoji["name"]
    return unless group = groups[name]
    filename = emoji["filename"] || name

    Emoji.new.tap do |e|
      e.name = name
      e.tonable = Emoji.tonable_emojis.include?(name)
      e.url = Emoji.url_for(filename)
      e.group = group
      e.search_aliases = search_aliases[name] || []
    end
  end

  def self.url_for(name)
    name = name.delete_prefix(":").delete_suffix(":").gsub(/(.+):t([1-6])/, '\1/\2')
    if SiteSetting.external_emoji_url.blank?
      "#{Discourse.base_path}/images/emoji/#{SiteSetting.emoji_set}/#{name}.png?v=#{EMOJI_VERSION}"
    else
      "#{SiteSetting.external_emoji_url}/#{SiteSetting.emoji_set}/#{name}.png?v=#{EMOJI_VERSION}"
    end
  end

  def self.cache_key(name)
    "#{name}#{cache_postfix}"
  end

  def self.cache_postfix
    ":v#{EMOJI_VERSION}:#{Plugin::CustomEmoji.cache_key}"
  end

  def self.clear_cache
    %w[custom standard translations allowed denied all].each do |key|
      Discourse.cache.delete(cache_key("#{key}_emojis"))
    end
    global_emoji_cache.clear
    site_emoji_cache.clear
  end

  def self.groups_file
    @groups_file ||= "#{Rails.root}/lib/emoji/groups.json"
  end

  def self.groups
    @groups ||=
      begin
        groups = {}

        File
          .open(groups_file, "r:UTF-8") { |f| JSON.parse(f.read) }
          .each { |group| group["icons"].each { |icon| groups[icon["name"]] = group["name"] } }

        groups
      end
  end

  def self.db_file
    @db_file ||= "#{Rails.root}/lib/emoji/db.json"
  end

  def self.db
    @db ||= File.open(db_file, "r:UTF-8") { |f| JSON.parse(f.read) }
  end

  def self.load_standard
    db["emojis"].map { |e| Emoji.create_from_db_item(e) }.compact
  end

  def self.load_allowed
    denied_emojis = denied
    all_emojis = load_standard + load_custom

    if denied_emojis.present?
      all_emojis.reject { |e| denied_emojis.include?(e.name) }
    else
      all_emojis
    end
  end

  def self.load_denied
    if SiteSetting.emoji_deny_list.present?
      denied_emoji = SiteSetting.emoji_deny_list.split("|")
      if denied_emoji.size > 0
        denied_emoji.concat(denied_emoji.flat_map { |e| Emoji.aliases[e] }.compact)
      end
    end
  end

  def self.load_custom
    result = []

    if !GlobalSetting.skip_db?
      CustomEmoji
        .includes(:upload)
        .order(:name)
        .each do |emoji|
          result << Emoji.new.tap do |e|
            e.name = emoji.name
            e.url = emoji.upload&.url
            e.group = emoji.group || DEFAULT_GROUP
            e.created_by = User.where(id: emoji.user_id).pick(:username)
          end
        end
    end

    Plugin::CustomEmoji.emojis.each do |group, emojis|
      emojis.each do |name, url|
        result << Emoji.new.tap do |e|
          e.name = name
          url = (Discourse.base_path + url) if url[%r{\A/[^/]}]
          e.url = url
          e.group = group || DEFAULT_GROUP
        end
      end
    end

    result
  end

  def self.load_translations
    db["translations"]
  end

  def self.base_directory
    "public#{base_url}"
  end

  def self.base_url
    db = RailsMultisite::ConnectionManagement.current_db
    "#{Discourse.base_path}/uploads/#{db}/_emoji"
  end

  def self.replacement_code(code)
    code.split("-").map!(&:hex).pack("U*")
  end

  def self.unicode_replacements
    @unicode_replacements ||=
      begin
        replacements = {}
        is_tonable_emojis = Emoji.tonable_emojis
        fitzpatrick_scales = FITZPATRICK_SCALE.map { |scale| scale.to_i(16) }

        db["emojis"].each do |e|
          name = e["name"]

          # special cased as we prefer to keep these as symbols
          next if name == "registered"
          next if name == "copyright"
          next if name == "tm"
          next if name == "left_right_arrow"

          code = replacement_code(e["code"])
          next unless code

          replacements[code] = name
          if is_tonable_emojis.include?(name)
            fitzpatrick_scales.each_with_index do |scale, index|
              toned_code = code.codepoints.insert(1, scale).pack("U*")
              replacements[toned_code] = "#{name}:t#{index + 2}"
            end
          end
        end

        replacements["\u{2639}"] = "frowning"
        replacements["\u{263B}"] = "slight_smile"
        replacements["\u{2661}"] = "heart"
        replacements["\u{2665}"] = "heart"

        replacements
      end
  end

  def self.unicode_unescape(string)
    PrettyText.escape_emoji(string)
  end

  def self.gsub_emoji_to_unicode(str)
    str.gsub(/:([\w\-+]*(?::t\d)?):/) { |name| Emoji.lookup_unicode($1) || name } if str
  end

  def self.lookup_unicode(name)
    return "" if denied&.include?(name)

    @reverse_map ||=
      begin
        map = {}
        is_tonable_emojis = Emoji.tonable_emojis

        db["emojis"].each do |e|
          next if e["name"] == "tm"

          code = replacement_code(e["code"])
          next unless code

          map[e["name"]] = code
          if is_tonable_emojis.include?(e["name"])
            FITZPATRICK_SCALE.each_with_index do |scale, index|
              toned_code = (code.codepoints.insert(1, scale.to_i(16))).pack("U*")
              map["#{e["name"]}:t#{index + 2}"] = toned_code
            end
          end
        end

        Emoji.aliases.each do |key, alias_names|
          next unless alias_code = map[key]
          alias_names.each { |alias_name| map[alias_name] = alias_code }
        end

        map
      end
    @reverse_map[name]
  end

  def self.unicode_replacements_json
    @unicode_replacements_json ||= unicode_replacements.to_json
  end

  def self.codes_to_img(str)
    return if str.blank?

    str =
      str.gsub(/:([\w\-+]*(?::t\d)?):/) do |name|
        code = $1

        if code && Emoji.custom?(code)
          emoji = Emoji[code]
          "<img src=\"#{emoji.url}\" title=\"#{code}\" class=\"emoji\" alt=\"#{code}\" loading=\"lazy\" width=\"20\" height=\"20\">"
        elsif code && Emoji.exists?(code)
          "<img src=\"#{Emoji.url_for(code)}\" title=\"#{code}\" class=\"emoji\" alt=\"#{code}\" loading=\"lazy\" width=\"20\" height=\"20\">"
        else
          name
        end
      end
  end

  def self.sanitize_emoji_name(name)
    name.gsub(/[^a-z0-9\+\-]+/i, "_").gsub(/_{2,}/, "_").downcase
  end
end
