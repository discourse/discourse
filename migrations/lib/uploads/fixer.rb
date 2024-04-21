# frozen_string_literal: true

require_relative "./base"

module Migrations
  module Uploads
    class Fixer < Base
      def initialize(settings)
        @settings = settings

        @source_db = create_connection(settings[:output_db_path])
      end

      def self.run!(settings)
        puts "Fixing missing uploads..."

        new(settings).run!
      end

      def run!
        queue = SizedQueue.new(QUEUE_SIZE)
        consumer_threads = []

        max_count =
          @source_db.get_first_value("SELECT COUNT(*) FROM uploads WHERE upload IS NOT NULL")

        binding
        producer_thread =
          Thread.new do
            query(
              "SELECT id, upload FROM uploads WHERE upload IS NOT NULL ORDER BY rowid DESC",
              @source_db,
            ).tap do |result_set|
              result_set.each { |row| queue << row }
              result_set.close
            end
          end

        status_queue = SizedQueue.new(QUEUE_SIZE)
        status_thread =
          Thread.new do
            error_count = 0
            current_count = 0
            missing_count = 0

            while !(result = status_queue.pop).nil?
              current_count += 1

              case result[:status]
              when :ok
                # ignore
              when :error
                error_count += 1
                puts "Error in #{result[:id]}"
              when :missing
                missing_count += 1
                puts "Missing #{result[:id]}"

                @output_db.execute("DELETE FROM uploads WHERE id = ?", result[:id])
                Upload.delete_by(id: result[:upload_id])
              end

              error_count_text = error_count > 0 ? "#{error_count} errors".red : "0 errors"

              print "\r%7d / %7d (%s, %s missing)" %
                      [current_count, max_count, error_count_text, missing_count]
            end
          end

        store = Discourse.store

        (Etc.nprocessors * @settings[:thread_count_factor] * 2).to_i.times do |index|
          consumer_threads << Thread.new do
            Thread.current.name = "worker-#{index}"
            fake_upload = OpenStruct.new(url: "")
            while (row = queue.pop)
              begin
                upload = JSON.parse(row["upload"])
                fake_upload.url = upload["url"]
                path = add_multisite_prefix(store.get_path_for_upload(fake_upload))

                file_exists =
                  if store.external?
                    store.object_from_path(path).exists?
                  else
                    File.exist?(File.join(store.public_dir, path))
                  end

                if file_exists
                  status_queue << { id: row["id"], upload_id: upload["id"], status: :ok }
                else
                  status_queue << { id: row["id"], upload_id: upload["id"], status: :missing }
                end
              rescue StandardError => e
                puts e.message
                status_queue << { id: row["id"], upload_id: upload["id"], status: :error }
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
