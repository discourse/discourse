# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        class Groups
          def initialize(values, matcher, target:, dry_run:)
            @values = values
            @matcher = matcher
            @target = target
            @dry_run = dry_run
          end

          def call(entry)
            keys = entry["match"].presence || { "name" => entry["name"] }
            match = @matcher.resolve(:group, keys) { |id| ::Group.exists?(id:) }
            desired = Attributes.desired(entry, Plan::Rules::GROUP_ATTRIBUTES, @values)

            return create(entry, desired) if match.nil?

            group = ::Group.find(match.id)
            differences = Attributes.differences(group, desired)
            matched = "matched by #{match.strategy}"
            return :unchanged, matched if differences.empty?

            unless @dry_run
              group.assign_attributes(differences)
              group.save!
            end
            [:changed, matched]
          end

          private

          def create(entry, desired)
            if @target == "import" || entry["automatic"]
              raise SkipItem,
                    "no matching group found (tried #{(entry["match"] || {}).keys.join(", ").presence || "name"})"
            end
            raise Error, "group name is missing" if entry["name"].blank?
            return :changed, "would be created" if @dry_run

            group = ::Group.new(name: entry["name"])
            group.assign_attributes(desired)
            group.save!
            [:changed, "created"]
          end
        end
      end
    end
  end
end
