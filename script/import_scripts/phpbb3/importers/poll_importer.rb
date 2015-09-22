module ImportScripts::PhpBB3
  class PollImporter
    POLL_PLUGIN_NAME = 'poll'

    # @param lookup [ImportScripts::LookupContainer]
    # @param database [ImportScripts::PhpBB3::Database_3_0 | ImportScripts::PhpBB3::Database_3_1]
    # @param text_processor [ImportScripts::PhpBB3::TextProcessor]
    def initialize(lookup, database, text_processor)
      @lookup = lookup
      @database = database
      @text_processor = text_processor

      poll_plugin = Discourse.plugins.find { |p| p.metadata.name == POLL_PLUGIN_NAME }.singleton_class
      @default_poll_name = poll_plugin.const_get(:DEFAULT_POLL_NAME)
      @polls_field = poll_plugin.const_get(:POLLS_CUSTOM_FIELD)
      @votes_field = poll_plugin.const_get(:VOTES_CUSTOM_FIELD)
    end

    # @param poll [ImportScripts::PhpBB3::Poll]
    def map_poll(topic_id, poll)
      options = get_poll_options(topic_id)
      poll_text = get_poll_text(options, poll)
      extracted_poll = extract_default_poll(topic_id, poll_text)

      update_poll(extracted_poll, options, topic_id, poll)

      mapped_poll = {
        raw: poll_text,
        custom_fields: {}
      }

      add_polls_field(mapped_poll[:custom_fields], extracted_poll)
      add_vote_fields(mapped_poll[:custom_fields], topic_id, poll)
      mapped_poll
    end

    protected

    def get_poll_options(topic_id)
      rows = @database.fetch_poll_options(topic_id)
      options_by_text = {}

      rows.each do |row|
        option_text = @text_processor.process_raw_text(row[:poll_option_text]).delete("\n")

        if options_by_text.key?(option_text)
          # phpBB allows duplicate options (why?!) - we need to merge them
          option = options_by_text[option_text]
          option[:ids] << row[:poll_option_id]
          option[:votes] += row[:poll_option_total]
        else
          options_by_text[option_text] = {
            ids: [row[:poll_option_id]],
            text: option_text,
            votes: row[:poll_option_total]
          }
        end
      end

      options_by_text.values
    end

    # @param options [Array]
    # @param poll [ImportScripts::PhpBB3::Poll]
    def get_poll_text(options, poll)
      poll_text = "#{poll.title}\n"

      if poll.max_options > 1
        poll_text << "[poll type=multiple max=#{poll.max_options}]"
      else
        poll_text << '[poll]'
      end

      options.each do |option|
        poll_text << "\n- #{option[:text]}"
      end

      poll_text << "\n[/poll]"
    end

    def extract_default_poll(topic_id, poll_text)
      extracted_polls = DiscoursePoll::Poll::extract(poll_text, topic_id)
      extracted_polls.each do |poll|
        return poll if poll['name'] == @default_poll_name
      end
    end

    # @param poll [ImportScripts::PhpBB3::Poll]
    def update_poll(default_poll, imported_options, topic_id, poll)
      default_poll['voters'] = @database.count_voters(topic_id) # this includes anonymous voters
      default_poll['status'] = poll.has_ended? ? :open : :closed

      default_poll['options'].each_with_index do |option, index|
        imported_option = imported_options[index]
        option['votes'] = imported_option[:votes]
        poll.add_option_id(imported_option[:ids], option['id'])
      end
    end

    def add_polls_field(custom_fields, default_poll)
      custom_fields[@polls_field] = {@default_poll_name => default_poll}
    end

    # @param custom_fields [Hash]
    # @param poll [ImportScripts::PhpBB3::Poll]
    def add_vote_fields(custom_fields, topic_id, poll)
      rows = @database.fetch_poll_votes(topic_id)
      warned = false

      rows.each do |row|
        option_id = poll.option_id_from_imported_option_id(row[:poll_option_id])
        user_id = @lookup.user_id_from_imported_user_id(row[:user_id])

        if option_id.present? && user_id.present?
          key = "#{@votes_field}-#{user_id}"

          if custom_fields.key?(key)
            votes = custom_fields[key][@default_poll_name]
          else
            votes = []
            custom_fields[key] = {@default_poll_name => votes}
          end

          votes << option_id
        elsif !warned
          warned = true
          Rails.logger.warn("Topic with id #{topic_id} has invalid votes.")
        end
      end
    end
  end

  class Poll
    attr_reader :title
    attr_reader :max_options

    def initialize(title, max_options, end_timestamp)
      @title = title
      @max_options = max_options
      @end_timestamp = end_timestamp
      @option_ids = {}
    end

    def has_ended?
      @end_timestamp.nil? || Time.zone.at(@end_timestamp) > Time.now
    end

    def add_option_id(imported_ids, option_id)
      imported_ids.each { |imported_id| @option_ids[imported_id] = option_id }
    end

    def option_id_from_imported_option_id(imported_id)
      @option_ids[imported_id]
    end
  end
end
