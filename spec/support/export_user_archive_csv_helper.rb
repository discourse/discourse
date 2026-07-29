# frozen_string_literal: true

module ExportUserArchiveCsvHelper
  def export_user_archive_component_csv(job:, component:)
    data_rows = []
    csv_out =
      CSV.generate do |csv|
        csv << job.get_header(component)
        job.public_send(:"#{component}_export") do |row|
          csv << row
          data_rows << Jobs::ExportUserArchive::HEADER_ATTRS_FOR[component]
            .zip(row.map(&:to_s))
            .to_h
            .with_indifferent_access
        end
      end
    [data_rows, csv_out]
  end
end
