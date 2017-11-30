require_relative 'database'
require 'json'
require 'yaml'

module ImportScripts::Mbox
  class Indexer
    # @param database [ImportScripts::Mbox::Database]
    # @param settings [ImportScripts::Mbox::Settings]
    def initialize(database, settings)
      @database = database
      @root_directory = settings.data_dir
      @split_regex = settings.split_regex
    end

    def execute
      directories = Dir.glob(File.join(@root_directory, '*'))
      directories.select! { |f| File.directory?(f) }
      directories.sort!

      directories.each do |directory|
        puts "indexing files in #{directory}"
        category = index_category(directory)
        index_emails(directory, category[:name])
      end

      puts '', 'indexing replies and users'
      @database.update_in_reply_to_of_emails
      @database.sort_emails
      @database.fill_users_from_emails
    end

    private

    METADATA_FILENAME = 'metadata.yml'.freeze

    def index_category(directory)
      metadata_file = File.join(directory, METADATA_FILENAME)

      if File.exist?(metadata_file)
        # workaround for YML files that contain classname in file header
        yaml = File.read(metadata_file).sub(/^--- !.*$/, '---')
        metadata = YAML.load(yaml)
      else
        metadata = {}
      end

      category = {
        name: metadata['name'].presence || File.basename(directory),
        description: metadata['description']
      }

      @database.insert_category(category)
      category
    end

    def index_emails(directory, category_name)
      all_messages(directory, category_name) do |receiver, filename, first_line_number, last_line_number|
        msg_id = receiver.message_id
        parsed_email = receiver.mail
        from_email, from_display_name = receiver.parse_from_field(parsed_email)
        body, elided, format = receiver.select_body
        reply_message_ids = extract_reply_message_ids(parsed_email)

        email = {
          msg_id: msg_id,
          from_email: from_email,
          from_name: from_display_name,
          subject: extract_subject(receiver, category_name),
          email_date: parsed_email.date&.to_s,
          raw_message: receiver.raw_email,
          body: body,
          elided: elided,
          format: format,
          attachment_count: receiver.attachments.count,
          charset: parsed_email.charset&.downcase,
          category: category_name,
          filename: File.basename(filename),
          first_line_number: first_line_number,
          last_line_number: last_line_number
        }

        @database.insert_email(email)
        @database.insert_replies(msg_id, reply_message_ids) unless reply_message_ids.empty?
      end
    end

    def imported_file_checksums(category_name)
      rows = @database.fetch_imported_files(category_name)
      rows.each_with_object({}) do |row, hash|
        hash[row['filename']] = row['checksum']
      end
    end

    def all_messages(directory, category_name)
      checksums = imported_file_checksums(category_name)

      Dir.foreach(directory) do |filename|
        filename = File.join(directory, filename)
        next if ignored_file?(filename, checksums)

        puts "indexing #{filename}"

        if @split_regex.present?
          each_mail(filename) do |raw_message, first_line_number, last_line_number|
            receiver = read_mail_from_string(raw_message)
            yield receiver, filename, first_line_number, last_line_number if receiver.present?
          end
        else
          receiver = read_mail_from_file(filename)
          yield receiver, filename if receiver.present?
        end

        mark_as_fully_indexed(category_name, filename)
      end
    end

    def mark_as_fully_indexed(category_name, filename)
      imported_file = {
        category: category_name,
        filename: filename,
        checksum: calc_checksum(filename)
      }

      @database.insert_imported_file(imported_file)
    end

    def each_mail(filename)
      raw_message = ''
      first_line_number = 1
      last_line_number = 0

      each_line(filename) do |line|
        line = line.scrub

        if line =~ @split_regex && last_line_number.positive?
          yield raw_message, first_line_number, last_line_number
          raw_message = ''
          first_line_number = last_line_number + 1
        else
          raw_message << line
        end

        last_line_number += 1
      end

      yield raw_message, first_line_number, last_line_number if raw_message.present?
    end

    def each_line(filename)
      raw_file = File.open(filename, 'r')
      text_file = filename.end_with?('.gz') ? Zlib::GzipReader.new(raw_file) : raw_file

      text_file.each_line do |line|
        yield line
      end
    ensure
      raw_file.close if raw_file
    end

    def read_mail_from_file(filename)
      raw_message = File.read(filename)
      read_mail_from_string(raw_message)
    end

    def read_mail_from_string(raw_message)
      Email::Receiver.new(raw_message) unless raw_message.blank?
    end

    def extract_reply_message_ids(mail)
      message_ids = [mail.in_reply_to, Email::Receiver.extract_references(mail.references)]
      message_ids.flatten!
      message_ids.select!(&:present?)
      message_ids.uniq!
      message_ids.first(20)
    end

    def extract_subject(receiver, list_name)
      subject = receiver.subject
      return nil if subject.blank?

      # TODO: make the list name (or maybe multiple names) configurable
      # Strip mailing list name from subject
      subject = subject.gsub(/\[#{Regexp.escape(list_name)}\]/, '').strip

      clean_subject(subject)
    end

    # TODO: refactor and move prefixes to settings
    def clean_subject(subject)
      original_length = subject.length

      # Strip Reply prefix from title (Standard and localized)
      subject = subject.gsub(/^Re: */i, '')
      subject = subject.gsub(/^R: */i, '') #Italian
      subject = subject.gsub(/^RIF: */i, '') #Italian

      # Strip Forward prefix from title (Standard and localized)
      subject = subject.gsub(/^Fwd: */i, '')
      subject = subject.gsub(/^I: */i, '') #Italian

      subject.strip

      # In case of mixed localized prefixes there could be many of them
      # if the mail client didn't strip the localized ones
      if original_length > subject.length
        clean_subject(subject)
      else
        subject
      end
    end

    def ignored_file?(filename, checksums)
      File.directory?(filename) || hidden_file?(filename) ||
        metadata_file?(filename) || fully_indexed?(filename, checksums)
    end

    def hidden_file?(filename)
      File.basename(filename).start_with?('.')
    end

    def metadata_file?(filename)
      File.basename(filename) == METADATA_FILENAME
    end

    def fully_indexed?(filename, checksums)
      checksum = checksums[filename]
      checksum.present? && calc_checksum(filename) == checksum
    end

    def calc_checksum(filename)
      Digest::SHA256.file(filename).hexdigest
    end
  end
end
