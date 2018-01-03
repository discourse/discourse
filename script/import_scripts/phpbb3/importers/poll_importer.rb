module ImportScripts::PhpBB3
  class PollImporter
    # @param lookup [ImportScripts::LookupContainer]
    # @param database [ImportScripts::PhpBB3::Database_3_0 | ImportScripts::PhpBB3::Database_3_1]
    # @param text_processor [ImportScripts::PhpBB3::TextProcessor]
    def initialize(lookup, database, text_processor)
      @lookup = lookup
      @database = database
      @text_processor = text_processor
    end

    # @param poll [ImportScripts::PhpBB3::Poll]
    def map_poll(topic_id, poll)
      options = get_poll_options(topic_id)
      poll_text = get_poll_text(options, poll)
      extracted_poll = extract_default_poll(topic_id, poll_text)

      return if extracted_poll.nil?

      update_poll_metadata(extracted_poll, topic_id, poll)
      update_poll_options(extracted_poll, options, poll)

      mapped_poll = {
        raw: poll_text,
        custom_fields: {}
      }

      add_poll_to_custom_fields(mapped_poll[:custom_fields], extracted_poll)
      add_votes_to_custom_fields(mapped_poll[:custom_fields], topic_id, poll)

      mapped_poll
    end

    protected

    def get_poll_options(topic_id)
      rows = @database.fetch_poll_options(topic_id)
      options_by_text = Hash.new { |h, k| h[k] = { ids: [], total_votes: 0, anonymous_votes: 0 } }

      rows.each do |row|
        option_text = @text_processor.process_raw_text(row[:poll_option_text]).delete("\n")

        # phpBB allows duplicate options (why?!) - we need to merge them
        option = options_by_text[option_text]
        option[:ids] << row[:poll_option_id]
        option[:text] = option_text
        option[:total_votes] += row[:total_votes]
        option[:anonymous_votes] += row[:anonymous_votes]
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
        return poll if poll['name'] == DiscoursePoll::DEFAULT_POLL_NAME
      end

      puts "Failed to extract poll for topic id #{topic_id}. The poll text is:"
      puts poll_text
    end

    # @param poll [ImportScripts::PhpBB3::Poll]
    def update_poll_metadata(extracted_poll, topic_id, poll)
      row = @database.get_voters(topic_id)

      extracted_poll['voters'] = row[:total_voters]
      extracted_poll['anonymous_voters'] = row[:anonymous_voters] if row[:anonymous_voters] > 0
      extracted_poll['status'] = poll.has_ended? ? :open : :closed
    end

    # @param poll [ImportScripts::PhpBB3::Poll]
    def update_poll_options(extracted_poll, imported_options, poll)
      extracted_poll['options'].each_with_index do |option, index|
        imported_option = imported_options[index]
        option['votes'] = imported_option[:total_votes]
        option['anonymous_votes'] = imported_option[:anonymous_votes] if imported_option[:anonymous_votes] > 0
        poll.add_option_id(imported_option[:ids], option['id'])
      end
    end

    # @param custom_fields [Hash]
    def add_poll_to_custom_fields(custom_fields, extracted_poll)
      custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD] = { DiscoursePoll::DEFAULT_POLL_NAME => extracted_poll }
    end

    # @param custom_fields [Hash]
    # @param poll [ImportScripts::PhpBB3::Poll]
    def add_votes_to_custom_fields(custom_fields, topic_id, poll)
      rows = @database.fetch_poll_votes(topic_id)
      votes = {}

      rows.each do |row|
        option_id = poll.option_id_from_imported_option_id(row[:poll_option_id])
        user_id = @lookup.user_id_from_imported_user_id(row[:user_id])

        if option_id.present? && user_id.present?
          user_votes = votes["#{user_id}"] ||= {}
          user_votes = user_votes[DiscoursePoll::DEFAULT_POLL_NAME] ||= []
          user_votes << option_id
        end
      end

      custom_fields[DiscoursePoll::VOTES_CUSTOM_FIELD] = votes
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
