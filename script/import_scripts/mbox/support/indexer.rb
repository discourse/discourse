# frozen_string_literal: true

require_relative "database"
require "json"
require "yaml"

module ImportScripts::Mbox
  class Indexer
    # @param database [ImportScripts::Mbox::Database]
    # @param settings [ImportScripts::Mbox::Settings]
    def initialize(database, settings)
      @database = database
      @settings = settings
      @split_regex = settings.split_regex
    end

    def execute
      directories = Dir.glob(File.join(@settings.data_dir, "*"))
      directories.select! { |f| File.directory?(f) }
      directories.sort!

      directories.each do |directory|
        puts "indexing files in #{directory}"
        category = index_category(directory)
        index_emails(directory, category[:name])
      end

      puts "", "indexing replies and users"
      if @settings.group_messages_by_subject
        @database.sort_emails_by_subject
        @database.update_in_reply_to_by_email_subject
      else
        @database.update_in_reply_to_of_emails
        @database.sort_emails_by_date_and_reply_level
      end

      @database.fill_users_from_emails
    end

    private

    METADATA_FILENAME = "metadata.yml"
    IGNORED_FILE_EXTENSIONS = %w[.dbindex .dbnames .digest .subjects .yml].freeze

    def index_category(directory)
      metadata_file = File.join(directory, METADATA_FILENAME)

      if File.exist?(metadata_file)
        # workaround for YML files that contain classname in file header
        yaml = File.read(metadata_file).sub(/^--- !.*$/, "---")
        metadata = YAML.safe_load(yaml)
      else
        metadata = {}
      end

      category = {
        name: metadata["name"].presence || File.basename(directory),
        description: metadata["description"],
        parent_category_id: metadata["parent_category_id"].presence,
      }

      @database.insert_category(category)
      category
    end

    def index_emails(directory, category_name)
      all_messages(directory, category_name) do |receiver, filename, opts|
        begin
          msg_id = receiver.message_id
          parsed_email = receiver.mail

          from_email, from_display_name = receiver.parse_from_field(parsed_email)

          if @settings.fix_mailman_via_addresses
            # Detect cases like this and attempt to get actual sender from other headers:
            #    From: Jane Smith via ListName <ListName@lists.example.com>

            if receiver.mail["X-Mailman-Version"] && from_display_name =~ /\bvia \S+$/i
              email_from_from_line = opts[:from_line].scan(/From (\S+)/).flatten.first
              a = Mail::Address.new(email_from_from_line)
              from_email = a.address
              from_display_name = a.display_name
              # if name is not available there, look for it in Reply-To
              if from_display_name.nil?
                reply_to = receiver.mail.to_s.scan(/[\n\r]Reply-To: ([^\r\n]+)/).flatten.first
                from_display_name = Mail::Address.new(reply_to).display_name
              end
            end
          end

          from_email = from_email.sub(/^(.*)=/, "") if @settings.elide_equals_in_addresses

          body, elided, format = receiver.select_body
          reply_message_ids = extract_reply_message_ids(parsed_email)

          email = {
            msg_id: msg_id,
            from_email: from_email,
            from_name: from_display_name,
            subject: extract_subject(receiver, category_name),
            email_date: timestamp(parsed_email.date),
            raw_message: receiver.raw_email,
            body: body,
            elided: elided,
            format: format,
            attachment_count: receiver.attachments.count,
            charset: parsed_email.charset&.downcase,
            category: category_name,
            filename: File.basename(filename),
            first_line_number: opts[:first_line_number],
            last_line_number: opts[:last_line_number],
            index_duration: (monotonic_time - opts[:start_time]).round(4),
          }

          @database.transaction do |db|
            db.insert_email(email)
            db.insert_replies(msg_id, reply_message_ids) unless reply_message_ids.empty?
          end
        rescue StandardError => e
          if opts[:first_line_number] && opts[:last_line_number]
            STDERR.puts "Failed to index message in #{filename} at lines #{opts[:first_line_number]}-#{opts[:last_line_number]}"
          else
            STDERR.puts "Failed to index message in #{filename}"
          end

          STDERR.puts e.message
          STDERR.puts e.backtrace.inspect
        end
      end
    end

    def imported_file_checksums(category_name)
      rows = @database.fetch_imported_files(category_name)
      rows.each_with_object({}) do |row, hash|
        filename = File.basename(row["filename"])
        hash[filename] = row["checksum"]
      end
    end

    def all_messages(directory, category_name)
      checksums = imported_file_checksums(category_name)

      Dir.foreach(directory) do |filename|
        filename = File.join(directory, filename)
        next if ignored_file?(filename, checksums)

        puts "indexing #{filename}"

        if @split_regex.present?
          each_mail(filename) do |raw_message, first_line_number, last_line_number, from_line|
            opts = {
              first_line_number: first_line_number,
              last_line_number: last_line_number,
              start_time: monotonic_time,
              from_line: from_line,
            }
            receiver = read_mail_from_string(raw_message)
            yield receiver, filename, opts if receiver.present?
          end
        else
          opts = { start_time: monotonic_time }
          receiver = read_mail_from_file(filename)
          yield receiver, filename, opts if receiver.present?
        end

        mark_as_fully_indexed(category_name, filename)
      end
    end

    def mark_as_fully_indexed(category_name, filename)
      imported_file = {
        category: category_name,
        filename: File.basename(filename),
        checksum: calc_checksum(filename),
      }

      @database.insert_imported_file(imported_file)
    end

    def each_mail(filename)
      raw_message = +""
      first_line_number = 1
      last_line_number = 0

      from_line = nil

      each_line(filename) do |line|
        if line.scrub =~ @split_regex
          if last_line_number > 0
            yield raw_message, first_line_number, last_line_number, from_line
            raw_message = +""
            first_line_number = last_line_number + 1
          end

          from_line = line
        else
          raw_message << line
        end

        last_line_number += 1
      end

      yield raw_message, first_line_number, last_line_number, from_line if raw_message.present?
    end

    def each_line(filename)
      raw_file = File.open(filename, "r")
      text_file = filename.end_with?(".gz") ? Zlib::GzipReader.new(raw_file) : raw_file

      text_file.each_line { |line| yield line }
    ensure
      raw_file.close if raw_file
    end

    def read_mail_from_file(filename)
      raw_message = File.read(filename)
      read_mail_from_string(raw_message)
    end

    def read_mail_from_string(raw_message)
      if raw_message.present?
        Email::Receiver.new(raw_message, convert_plaintext: true, skip_trimming: false)
      end
    end

    def extract_reply_message_ids(mail)
      Email::Receiver.extract_reply_message_ids(mail, max_message_id_count: 20)
    end

    def extract_subject(receiver, list_name)
      subject = receiver.subject
      subject.blank? ? nil : subject.strip.gsub(/\t+/, " ")
    end

    def ignored_file?(path, checksums)
      filename = File.basename(path)

      filename.start_with?(".") || filename == METADATA_FILENAME ||
        IGNORED_FILE_EXTENSIONS.include?(File.extname(filename)) ||
        fully_indexed?(path, filename, checksums)
    end

    def fully_indexed?(path, filename, checksums)
      checksum = checksums[filename]
      checksum.present? && calc_checksum(path) == checksum
    end

    def calc_checksum(filename)
      Digest::SHA256.file(filename).hexdigest
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def timestamp(datetime)
      Time.zone.at(datetime).to_i if datetime
    end
  end
end
