# frozen_string_literal: true

require_relative "./base"

module Migrations
  module Uploads
    class Uploader < Base
      def initialize(settings)
        @settings = settings

        @source_db = create_connection(@settings[:source_db_path])
        @output_db = settings.output_db
      end

      def self.run!(settings)
        puts "Uploading uploads..."

        new(settings).run!
      end

      def run!
        queue = SizedQueue.new(QUEUE_SIZE)
        consumer_threads = []

        if @settings[:delete_missing_uploads]
          puts "Deleting missing uploads from output database..."
          @output_db.execute(<<~SQL)
            DELETE FROM uploads
            WHERE upload IS NULL
          SQL
        end

        output_existing_ids = Set.new
        query("SELECT id FROM uploads", @output_db).tap do |result_set|
          result_set.each { |row| output_existing_ids << row["id"] }
          result_set.close
        end

        source_existing_ids = Set.new
        query("SELECT id FROM uploads", @source_db).tap do |result_set|
          result_set.each { |row| source_existing_ids << row["id"] }
          result_set.close
        end

        if (surplus_upload_ids = output_existing_ids - source_existing_ids).any?
          if @settings[:delete_surplus_uploads]
            puts "Deleting #{surplus_upload_ids.size} uploads from output database..."

            surplus_upload_ids.each_slice(TRANSACTION_SIZE) do |ids|
              placeholders = (["?"] * ids.size).join(",")
              @output_db.execute(<<~SQL, ids)
                DELETE FROM uploads
                WHERE id IN (#{placeholders})
              SQL
            end

            output_existing_ids -= surplus_upload_ids
          else
            puts "Found #{surplus_upload_ids.size} surplus uploads in output database. " \
                   "Run with `delete_surplus_uploads: true` to delete them."
          end

          surplus_upload_ids = nil
        end

        max_count = (source_existing_ids - output_existing_ids).size
        source_existing_ids = nil
        puts "Found #{output_existing_ids.size} existing uploads. #{max_count} are missing."

        producer_thread =
          Thread.new do
            query("SELECT * FROM uploads", @source_db).tap do |result_set|
              result_set.each { |row| queue << row unless output_existing_ids.include?(row["id"]) }
              result_set.close
            end
          end

        status_queue = SizedQueue.new(QUEUE_SIZE)
        status_thread =
          Thread.new do
            error_count = 0
            skipped_count = 0
            current_count = 0

            while !(params = status_queue.pop).nil?
              begin
                if params.delete(:skipped) == true
                  skipped_count += 1
                elsif (error_message = params.delete(:error)) || params[:upload].nil?
                  error_count += 1
                  puts "", "Failed to create upload: #{params[:id]} (#{error_message})", ""
                end

                @output_db.execute(<<~SQL, params)
                  INSERT INTO uploads (id, upload, markdown, skip_reason)
                  VALUES (:id, :upload, :markdown, :skip_reason)
                SQL
              rescue StandardError => e
                puts "", "Failed to insert upload: #{params[:id]} (#{e.message}))", ""
                error_count += 1
              end

              current_count += 1
              error_count_text = error_count > 0 ? "#{error_count} errors".red : "0 errors"

              print "\r%7d / %7d (%s, %d skipped)" %
                      [current_count, max_count, error_count_text, skipped_count]
            end
          end

        (Etc.nprocessors * @settings[:thread_count_factor]).to_i.times do |index|
          consumer_threads << Thread.new do
            Thread.current.name = "worker-#{index}"

            store = Discourse.store

            while (row = queue.pop)
              begin
                data_file = nil
                path = nil

                if row["data"].present?
                  data_file = Tempfile.new("discourse-upload", binmode: true)
                  data_file.write(row["data"])
                  data_file.rewind
                  path = data_file.path
                else
                  relative_path = row["relative_path"]
                  file_exists = false

                  @root_paths.each do |root_path|
                    path = File.join(root_path, relative_path, row["filename"])
                    break if (file_exists = File.exist?(path))

                    @settings[:path_replacements].each do |from, to|
                      path = File.join(root_path, relative_path.sub(from, to), row["filename"])
                      break if (file_exists = File.exist?(path))
                    end
                  end

                  if !file_exists
                    status_queue << {
                      id: row["id"],
                      upload: nil,
                      skipped: true,
                      skip_reason: "file not found",
                    }
                    next
                  end
                end

                retry_count = 0

                loop do
                  error_message = nil
                  upload =
                    copy_to_tempfile(path) do |file|
                      begin
                        UploadCreator.new(
                          file,
                          row["display_filename"] || row["filename"],
                          type: row["type"],
                        ).create_for(Discourse::SYSTEM_USER_ID)
                      rescue StandardError => e
                        error_message = e.message
                        nil
                      end
                    end

                  if (upload_okay = upload.present? && upload.persisted? && upload.errors.blank?)
                    upload_path = add_multisite_prefix(store.get_path_for_upload(upload))

                    file_exists =
                      if store.external?
                        store.object_from_path(upload_path).exists?
                      else
                        File.exist?(File.join(store.public_dir, upload_path))
                      end

                    unless file_exists
                      upload.destroy
                      upload = nil
                      upload_okay = false
                    end
                  end

                  if upload_okay
                    status_queue << {
                      id: row["id"],
                      upload: upload.attributes.to_json,
                      markdown: UploadMarkdown.new(upload).to_markdown,
                      skip_reason: nil,
                    }
                    break
                  elsif retry_count >= 3
                    error_message ||= upload&.errors&.full_messages&.join(", ") || "unknown error"
                    status_queue << {
                      id: row["id"],
                      upload: nil,
                      markdown: nil,
                      error: "too many retries: #{error_message}",
                      skip_reason: "too many retries",
                    }
                    break
                  end

                  retry_count += 1
                  sleep 0.25 * retry_count
                end
              rescue StandardError => e
                status_queue << {
                  id: row["id"],
                  upload: nil,
                  markdown: nil,
                  error: e.message,
                  skip_reason: "error",
                }
              ensure
                data_file&.close!
              end
            end
          end
        end

        producer_thread.join
        queue.close
        consumer_threads.each(&:join)
        status_queue.close
        status_thread.join
      end
    end
  end
end
