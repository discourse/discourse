# frozen_string_literal: true

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

    # @param poll_data [ImportScripts::PhpBB3::PollData]
    def create_raw(topic_id, poll_data)
      poll_data.options = get_poll_options(topic_id)
      get_poll_text(poll_data)
    end

    # @param post [Post]
    # @param poll_data [ImportScripts::PhpBB3::PollData]
    def update_poll(topic_id, post, poll_data)
      if poll = post.polls.first
        update_anonymous_voters(topic_id, poll_data, poll)
        create_votes(topic_id, poll_data, poll)
      end
    end

    protected

    def get_poll_options(topic_id)
      rows = @database.fetch_poll_options(topic_id)
      options_by_text = Hash.new { |h, k| h[k] = { ids: [], total_votes: 0, anonymous_votes: 0 } }

      rows.each do |row|
        option_text = get_option_text(row)

        # phpBB allows duplicate options (why?!) - we need to merge them
        option = options_by_text[option_text]
        option[:ids] << row[:poll_option_id]
        option[:text] = option_text
        option[:total_votes] += row[:total_votes]
        option[:anonymous_votes] += row[:anonymous_votes]
      end

      options_by_text.values
    end

    def get_option_text(row)
      text = @text_processor.process_raw_text(row[:poll_option_text])
      text.squish!
      text.gsub!(/^(\d+)\./, '\1\.')
      text
    end

    # @param poll_data [ImportScripts::PhpBB3::PollData]
    def get_poll_text(poll_data)
      title = @text_processor.process_raw_text(poll_data.title)
      text = +"#{title}\n\n"

      arguments = ["results=always"]
      arguments << "close=#{poll_data.close_time.iso8601}" if poll_data.close_time

      if poll_data.max_options > 1
        arguments << "type=multiple" << "max=#{poll_data.max_options}"
      else
        arguments << "type=regular"
      end

      text << "[poll #{arguments.join(' ')}]"

      poll_data.options.each do |option|
        text << "\n* #{option[:text]}"
      end

      text << "\n[/poll]"
    end

    # @param poll_data [ImportScripts::PhpBB3::PollData]
    # @param poll [Poll]
    def update_anonymous_voters(topic_id, poll_data, poll)
      row = @database.get_voters(topic_id)

      if row[:anonymous_voters] > 0
        poll.update!(anonymous_voters: row[:anonymous_voters])

        poll.poll_options.each_with_index do |option, index|
          imported_option = poll_data.options[index]

          if imported_option[:anonymous_votes] > 0
            option.update!(anonymous_votes: imported_option[:anonymous_votes])
          end
        end
      end
    end

    # @param poll_data [ImportScripts::PhpBB3::PollData]
    # @param poll [Poll]
    def map_poll_options(poll_data, poll)
      option_ids = {}

      poll.poll_options.each_with_index do |option, index|
        imported_option = poll_data.options[index]

        imported_option[:ids].each do |imported_id|
          option_ids[imported_id] = option.id
        end
      end

      option_ids
    end

    # @param poll_data [ImportScripts::PhpBB3::PollData]
    # @param poll [Poll]
    def create_votes(topic_id, poll_data, poll)
      mapped_option_ids = map_poll_options(poll_data, poll)
      rows = @database.fetch_poll_votes(topic_id)

      rows.each do |row|
        option_id = mapped_option_ids[row[:poll_option_id]]
        user_id = @lookup.user_id_from_imported_user_id(row[:user_id])

        if option_id.present? && user_id.present?
          PollVote.create!(poll: poll, poll_option_id: option_id, user_id: user_id)
        end
      end
    end
  end

  class PollData
    attr_reader :title
    attr_reader :max_options
    attr_reader :close_time
    attr_accessor :options

    def initialize(title, max_options, end_timestamp)
      @title = title
      @max_options = max_options
      @close_time = Time.zone.at(end_timestamp) if end_timestamp
    end
  end
end
