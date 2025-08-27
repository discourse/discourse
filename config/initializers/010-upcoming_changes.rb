# frozen_string_literal: true

Rails.application.config.to_prepare do
  RailsMultisite::ConnectionManagement.safe_each_connection do
    # load the core upcopming changes
    changes = YAML.load_file("config/upcoming_changes.yml", aliases: true)

    # HACK: This is all WIP, just getting something basic working for now
    changes.each do |change_identifier, change|
      UpcomingChange.find_or_create_by(identifier: change_identifier) do |uc|
        uc.description = change["description"]

        risk_level = change["risk_level"]&.downcase&.to_sym

        if risk_level && UpcomingChange.risk_levels.key?(risk_level)
          uc.risk_level = UpcomingChange.risk_levels[risk_level]
        else
          uc.risk_level = UpcomingChange.risk_levels[:low]
        end

        status = change["status"]&.downcase&.to_sym

        if status && UpcomingChange.statuses.key?(status)
          uc.status = UpcomingChange.statuses[status]
        else
          uc.status = UpcomingChange.statuses[:alpha]
        end

        type = change["type"]&.downcase&.to_sym
        if type && UpcomingChange.change_types.key?(type)
          uc.change_type = UpcomingChange.change_types[type]
        else
          uc.change_type = UpcomingChange.change_types[:feature]
        end
      end
    end

    # TODO: load the plugin upcoming changes

    # Get rid of any old upcoming changes that are no longer defined.
    UpcomingChange.where.not(identifier: changes.keys).destroy_all
  end
end
