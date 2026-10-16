# frozen_string_literal: true

require "io/console"
require "yaml"

module Migrations
  module Importer
    module Customizations
      # Secret values stay out of bundles unless asked for; apply gets them from
      # the environment or, interactively, from a hidden prompt.
      class Secrets
        # Names of settings, custom fields and plugin store keys whose value is
        # secret. Anchored at the end so settings *about* secrets, like
        # `min_password_length`, stay ordinary. Settings flagged `secret: true`
        # are covered separately.
        NAME_PATTERN =
          /(?:secrets?|secret_key|passw(?:or)?d|passcode|api_?key|private_key|access_key(?:_id)?|
            (?:\A|_)tokens?|credentials?|webhook_url|service_account_json|license_key)\z/xi

        # For key/value rows without secret flags (custom fields, plugin store),
        # where showing a secret is worse than hiding a harmless value.
        BROAD_NAME_PATTERN =
          /secret|passw(?:or)?d|token|api_?key|private_key|access_key|credential|_key\z|
            webhook_url|service_account|license/xi

        # Columns holding credentials, matched on any table.
        COLUMN_PATTERN =
          /\A(?:.*_)?(?:secret|password|password_hash|password_salt|salt|token|auth_token|access_token|
            refresh_token|api_key|private_key|key_hash|token_hash|code_hash|credentials?|invite_key|
            share_key)\z/x

        # Credential columns whose names don't give them away.
        TABLE_COLUMNS = {
          "discourse_workflows_credentials" => %w[data],
          "single_sign_on_records" => %w[last_payload],
          "user_associated_accounts" => %w[info extra credentials],
          "user_second_factors" => %w[data],
          "user_security_keys" => %w[credential_id],
        }.freeze

        ENV_PREFIX = "DISCO_SECRET_"

        def self.secret_name?(name)
          NAME_PATTERN.match?(name.to_s)
        end

        def self.possibly_secret_name?(name)
          BROAD_NAME_PATTERN.match?(name.to_s)
        end

        def self.secret_column?(table, column)
          COLUMN_PATTERN.match?(column) || TABLE_COLUMNS.fetch(table, []).include?(column)
        end

        # Settings flagged `secret: true` in core and bundled plugins, read from
        # the YAML files for when Rails isn't loaded. Unreadable files only mean
        # the name pattern has to do.
        def self.flagged_setting_names(root = Migrations.host_app_root, warnings: $stderr)
          files =
            [File.join(root, "config/site_settings.yml")] +
              Dir[File.join(root, "plugins/*/config/settings.yml")]

          files.each_with_object(Set.new) do |file, names|
            next unless File.exist?(file)

            yaml = YAML.safe_load_file(file, aliases: true)
            next unless yaml.is_a?(Hash)

            yaml.each_value do |category|
              next unless category.is_a?(Hash)
              category.each do |name, opts|
                names << name.to_s if opts.is_a?(Hash) && opts["secret"]
              end
            end
          rescue StandardError => e
            warnings.puts "could not read secret flags from #{file}: #{e.message}"
          end
        end

        def self.env_name(setting_name)
          "#{ENV_PREFIX}#{setting_name.to_s.upcase}"
        end

        def initialize(env: ENV, input: $stdin, output: $stdout)
          @env = env
          @input = input
          @output = output
          @fetched = {}
        end

        # Answers are remembered, so a retried setting doesn't ask twice.
        # @return [String, nil] nil when the secret is not available
        def fetch(setting_name)
          return @fetched[setting_name] if @fetched.key?(setting_name)

          @fetched[setting_name] = read(setting_name)
        end

        private

        def read(setting_name)
          value = @env[self.class.env_name(setting_name)]
          return value if value.present?
          return unless @input.respond_to?(:tty?) && @input.tty?

          @output.print("Value for secret setting #{setting_name} (input hidden, empty to skip): ")
          value = @input.noecho(&:gets).to_s.chomp
          @output.puts
          value.presence
        end
      end
    end
  end
end
