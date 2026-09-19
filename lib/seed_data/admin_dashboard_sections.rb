# frozen_string_literal: true

module SeedData
  class AdminDashboardSections
    def self.create
      AdminDashboardSectionConfiguration::KNOWN_SECTIONS.each do |section_id|
        next if AdminDashboardSection.exists?(section_id:)

        next_position = (AdminDashboardSection.maximum(:position) || -1) + 1
        AdminDashboardSection.create!(section_id:, position: next_position, visible: true)
      end
    end
  end
end
