# frozen_string_literal: true

module Migrations::Importer::Steps
  class Groups < ::Migrations::Importer::CopyStep
    DEFAULT_VISIBILITY_LEVEL = Group.visibility_levels[:public]
    DEFAULT_ALIAS_LEVEL = Group::ALIAS_LEVELS[:nobody]
    DEFAULT_NOTIFICATION_LEVEL = GroupUser.notification_levels[:watching]
    VISIBILITY_LEVELS = Group.visibility_levels.values.to_set.freeze
    ALIAS_LEVELS = Group::ALIAS_LEVELS.values.to_set.freeze
    TRUST_LEVELS = TrustLevel.levels.values.to_set.freeze
    NOTIFICATION_LEVELS = GroupUser.notification_levels.values.to_set.freeze
    DOMAIN_PROTOCOL_REGEX = %r{\Ahttps?://}.freeze
    DOMAIN_PATH_REGEX = %r{/.*\z}.freeze
    MAX_FULL_NAME_LENGTH = 100
    MAX_MEMBER_REQUEST_TEMPLATE_LENGTH = 5_000

    depends_on :uploads
    store_mapped_ids true

    requires_mapping :ids_by_name, "SELECT name, id FROM groups"
    requires_set :existing_ids, "SELECT id FROM groups"

    column_names %i[
                   id
                   allow_membership_requests
                   allow_unknown_sender_topic_replies
                   automatic_membership_email_domains
                   bio_cooked
                   bio_raw
                   created_at
                   updated_at
                   default_notification_level
                   flair_bg_color
                   flair_color
                   flair_icon
                   flair_upload_id
                   full_name
                   grant_trust_level
                   members_visibility_level
                   membership_request_template
                   mentionable_level
                   messageable_level
                   name
                   primary_group
                   public_admission
                   public_exit
                   publish_read_state
                   title
                   visibility_level
                 ]

    total_rows_query <<~SQL, MappingType::GROUPS
      SELECT COUNT(*)
      FROM groups g
           LEFT JOIN mapped.ids mapped_groups
            ON g.original_id = mapped_groups.original_id AND mapped_groups.type = ?
      WHERE mapped_groups.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::GROUPS, MappingType::UPLOADS
      SELECT g.*,
             mapped_flair_upload.discourse_id AS discourse_flair_upload_id
      FROM groups g
           LEFT JOIN mapped.ids mapped_groups
             ON g.original_id = mapped_groups.original_id AND mapped_groups.type = ?1
            LEFT JOIN mapped.ids mapped_flair_upload
              ON g.flair_upload_id = mapped_flair_upload.original_id AND mapped_flair_upload.type = ?2
      WHERE mapped_groups.original_id IS NULL
      ORDER BY g.ROWID
    SQL

    def initialize(intermediate_db, discourse_db, shared_data)
      super

      @unique_name_finder = ::Migrations::Importer::UniqueNameFinder.new(shared_data)
      @max_domains = SiteSetting.max_automatic_membership_email_domains
    end

    private

    def transform_row(row)
      # TODO(selase):
      #   1. Cook bio_raw
      #   2. Adopt importer framework warning implementation once available
      if (existing_id = row[:existing_id])
        row[:id] = resolve_existing_id(existing_id)

        return nil if row[:id]
      end

      row[:name] = @unique_name_finder.find_available_group_name(row[:name])
      row[:full_name] = sanitize_string(row[:full_name], MAX_FULL_NAME_LENGTH)
      row[:title] = sanitize_string(row[:title])
      row[:bio_raw] = sanitize_string(row[:bio_raw])
      row[:membership_request_template] = sanitize_string(
        row[:membership_request_template],
        MAX_MEMBER_REQUEST_TEMPLATE_LENGTH,
      )

      # TODO(selase):
      #   We need to ensure this isn't set to true for groups that are imported without an owner.
      #   Maybe we can do this as part of some other step after group users or potentially just
      #   join on group_users table here to determine if the group has an owner
      row[:allow_membership_requests] ||= false
      row[:allow_unknown_sender_topic_replies] ||= false
      row[:primary_group] ||= false
      row[:public_admission] ||= false
      row[:public_exit] ||= false
      row[:publish_read_state] ||= false

      row[:default_notification_level] = ensure_valid_value(
        value: row[:default_notification_level],
        allowed_set: NOTIFICATION_LEVELS,
        default_value: DEFAULT_NOTIFICATION_LEVEL,
      )
      row[:visibility_level] = ensure_valid_value(
        value: row[:visibility_level],
        allowed_set: VISIBILITY_LEVELS,
        default_value: DEFAULT_VISIBILITY_LEVEL,
      )
      row[:members_visibility_level] = ensure_valid_value(
        value: row[:members_visibility_level],
        allowed_set: VISIBILITY_LEVELS,
        default_value: DEFAULT_VISIBILITY_LEVEL,
      )
      row[:mentionable_level] = ensure_valid_value(
        value: row[:mentionable_level],
        allowed_set: ALIAS_LEVELS,
        default_value: DEFAULT_ALIAS_LEVEL,
      )
      row[:messageable_level] = ensure_valid_value(
        value: row[:messageable_level],
        allowed_set: ALIAS_LEVELS,
        default_value: DEFAULT_ALIAS_LEVEL,
      )

      unless row[:grant_trust_level].nil?
        row[:grant_trust_level] = ensure_valid_value(
          value: row[:grant_trust_level].presence,
          allowed_set: TRUST_LEVELS,
          default_value: nil,
        ) { |value, _default_value| puts "    #{row[:name]}: Invalid grant_trust_level '#{value}'" }
      end

      if row[:automatic_membership_email_domains].present?
        valid_domains = []

        row[:automatic_membership_email_domains]
          .split("|")
          .each do |domain|
            domain.sub!(DOMAIN_PROTOCOL_REGEX, "")
            domain.sub!(DOMAIN_PATH_REGEX, "")

            unless domain =~ Group::VALID_DOMAIN_REGEX
              puts "    #{row[:name]}: Invalid automatic_membership_email_domain '#{domain}'"
              next
            end

            if domain.length > Group::MAX_EMAIL_DOMAIN_LENGTH
              puts "    #{row[:name]}: Invalid automatic_membership_email_domain. Domain '#{domain}' is too long " \
                     "(Max: #{Group::MAX_EMAIL_DOMAIN_LENGTH})."
              next
            end

            valid_domains << domain
          end

        if valid_domains.size > @max_domains
          puts "    #{row[:name]}: Invalid automatic_membership_email_domain. Too many domains (Max: #{@max_domains})."

          valid_domains = valid_domains.take(@max_domains)
        end

        row[:automatic_membership_email_domains] = valid_domains.join("|")
      end

      row[:flair_upload_id] = row[:discourse_flair_upload_id]

      super
    end

    def resolve_existing_id(existing_id)
      if existing_id.match?(/\A\d+\z/)
        id = existing_id.to_i
        @existing_ids.include?(id) ? id : nil
      else
        @ids_by_name[existing_id]
      end
    end

    def sanitize_string(value, max_length = nil)
      return value if value.nil? || value.empty?

      value = value.dup
      value[max_length..-1] = "" if max_length && value.length > max_length
      value.scrub!
      value.strip!

      value.empty? ? nil : value
    end
  end
end
