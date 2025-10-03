#frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class SettingContext < Tool
        MAX_CONTEXT_TOKENS = 2000
        CODE_FILE_EXTENSIONS = "rb,js,gjs,hbs"

        class << self
          def rg_installed?
            if defined?(@rg_installed)
              @rg_installed
            else
              @rg_installed =
                begin
                  Discourse::Utils.execute_command("which", "rg")
                  true
                rescue Discourse::Utils::CommandError
                  false
                end
            end
          end

          def signature
            {
              name: name,
              description:
                "Will provide you with full context regarding a particular site setting in Discourse",
              parameters: [
                {
                  name: "setting_name",
                  description: "The name of the site setting we need context for",
                  type: "string",
                  required: true,
                },
              ],
            }
          end

          def name
            "setting_context"
          end
        end

        def setting_name
          @setting_name ||= parameters[:setting_name].to_s.downcase.gsub(" ", "_")
        end

        def invoke
          if !self.class.rg_installed?
            return(
              {
                setting_name: setting_name,
                context:
                  "This command requires the rg command line tool to be installed on the server",
              }
            )
          end

          if !SiteSetting.has_setting?(setting_name)
            { setting_name: setting_name, context: "This setting does not exist" }
          else
            description = SiteSetting.description(setting_name)
            result = +"# #{setting_name}\n#{description}\n\n"

            setting_info =
              find_setting_info(setting_name, [Rails.root.join("config", "site_settings.yml").to_s])
            if !setting_info
              setting_info =
                find_setting_info(setting_name, Dir[Rails.root.join("plugins/**/settings.yml")])
            end

            result << setting_info
            result << "\n\n"

            %w[lib app plugins].each do |dir|
              path = Rails.root.join(dir).to_s
              result << Discourse::Utils.execute_command(
                "rg",
                setting_name,
                path,
                "-g",
                "!**/spec/**",
                "-g",
                "!**/dist/**",
                "-g",
                "*.{#{CODE_FILE_EXTENSIONS}}",
                "-C",
                "10",
                "--color",
                "never",
                "--heading",
                "--no-ignore",
                chdir: path,
                success_status_codes: [0, 1],
              )
            end

            result.gsub!(/^#{Regexp.escape(Rails.root.to_s)}/, "")

            result =
              llm.tokenizer.truncate(
                result,
                MAX_CONTEXT_TOKENS,
                strict: SiteSetting.ai_strict_token_counting,
              )

            { setting_name: setting_name, context: result }
          end
        end

        private

        def find_setting_info(name, paths)
          path, result = nil

          paths.each do |search_path|
            result =
              Discourse::Utils.execute_command(
                "rg",
                name,
                search_path,
                "-g",
                "*.{#{CODE_FILE_EXTENSIONS}}",
                "-A",
                "10",
                "--color",
                "never",
                "--heading",
                success_status_codes: [0, 1],
              )
            if !result.blank?
              path = search_path
              break
            end
          end

          if result.blank?
            nil
          else
            rows = result.split("\n")
            leading_spaces = rows[0].match(/^\s*/)[0].length

            filtered = []

            rows.each do |row|
              if !filtered.blank?
                break if row.match(/^\s*/)[0].length <= leading_spaces
              end
              filtered << row
            end

            filtered.unshift("#{path}")
            filtered.join("\n")
          end
        end

        def description_args
          parameters.slice(:setting_name)
        end
      end
    end
  end
end
