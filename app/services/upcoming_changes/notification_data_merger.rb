# frozen_string_literal: true

module UpcomingChanges::NotificationDataMerger
  private

  def merge_change_data(existing_notification, new_change_name)
    if existing_notification
      existing_data = JSON.parse(existing_notification.data, symbolize_names: true)
      names =
        Array.wrap(existing_data[:upcoming_change_names] || [existing_data[:upcoming_change_name]])
      humanized =
        Array.wrap(
          existing_data[:upcoming_change_humanized_names] ||
            [existing_data[:upcoming_change_humanized_name]],
        )
      merged_names = (names.map(&:to_s) + [new_change_name.to_s]).uniq
      merged_humanized = (humanized + [SiteSetting.humanized_name(new_change_name)]).uniq
    else
      merged_names = [new_change_name.to_s]
      merged_humanized = [SiteSetting.humanized_name(new_change_name)]
    end

    {
      upcoming_change_names: merged_names,
      upcoming_change_humanized_names: merged_humanized,
      count: merged_names.size,
    }
  end
end
