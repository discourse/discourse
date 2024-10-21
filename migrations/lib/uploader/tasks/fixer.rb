# frozen_string_literal: true

module Migrations::Uploader
  module Tasks
    class Fixer < Base
      def run!
        puts "", "Fixing missing uploads..."

        status_thread
        create_consumer_threads

        producer_thread.join
        work_queue.close
        consumer_threads.each(&:join)
        status_queue.close
        status_thread.join
      end

      def max_count
        @max_count ||=
          uploads_db.db.query_single_splat("SELECT COUNT(*) FROM uploads WHERE upload IS NOT NULL")
      end

      def producer_thread
        Thread.new do
          uploads_db
            .db
            .query(
              "SELECT id, upload FROM uploads WHERE upload IS NOT NULL ORDER BY rowid DESC",
            ) { |row| work_queue << row }
        end
      end

      def create_consumer_threads
        thread_count.times { |index| consumer_threads << consumer_thread(index) }
      end

      def consumer_thread(index)
        Thread.new do
          Thread.current.name = "worker-#{index}"

          fake_upload = OpenStruct.new(url: "")

          while (row = work_queue.pop)
            process_row(row, fake_upload)
          end
        end
      end

      def status_thread
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

              uploads_db.db.execute("DELETE FROM uploads WHERE id = ?", result[:id])
              Upload.delete_by(id: result[:upload_id])
            end

            log_status(error_count, current_count, missing_count)
          end
        end
      end

      def process_row(row, fake_upload)
        upload = JSON.parse(row[:upload])
        fake_upload.url = upload[:url]
        path = add_multisite_prefix(discourse_store.get_path_for_upload(fake_upload))
        status = file_exists?(path) ? :ok : :missing

        update_status_queue(row, upload, status)
      rescue StandardError => error
        puts error.message
        status = :error
        update_status_queue(row, upload, status)
      end

      def file_exists?(path)
        if discourse_store.external?
          discourse_store.object_from_path(path).exists?
        else
          File.exist?(File.join(discourse_store.public_dir, path))
        end
      end

      def update_status_queue(row, upload, status)
        status_queue << { id: row["id"], upload_id: upload["id"], status: status }
      end

      def log_status(error_count, current_count, missing_count)
        error_count_text = error_count > 0 ? "#{error_count} errors".red : "0 errors"
        print "\r%7d / %7d (%s, %s missing)" %
                [current_count, max_count, error_count_text, missing_count]
      end
    end
  end
end
