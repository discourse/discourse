require 'fileutils'

module Capybara
  module Playwright
    module PageExtension
      def initialize(*args, **kwargs)
        if kwargs.empty?
          super(*args)
        else
          super(*args, **kwargs)
        end
        capybara_initialize
      end

      private def _update_internal_logger(internal_logger)
        @internal_logger = internal_logger
      end

      private def capybara_initialize
        @capybara_response_mutex = Mutex.new
        @capybara_last_response = nil
        @capybara_frames = []

        on('dialog', -> (dialog) {
          capybara_dialog_event_handler.handle_dialog(dialog)
        })
        on('download', -> (download) {
          FileUtils.mkdir_p(Capybara.save_path)
          dest = File.join(Capybara.save_path, download.suggested_filename)
          # download.save_as blocks main thread until download completes.
          Thread.new(dest) { |_dest| download.save_as(_dest) }
        })
        on('response', -> (response) {
          if response.request.navigation_request?
            capybara_set_last_response(response)
          end
        })
      end

      private def capybara_dialog_event_handler
        @capybara_dialog_event_handler ||= DialogEventHandler.new.tap do |h|
          h.default_handler = method(:capybara_on_unexpected_modal)
        end
      end

      private def capybara_on_unexpected_modal(dialog)
        @internal_logger.warn "Unexpected modal - \"#{dialog.message}\""
        if dialog.type == 'beforeunload'
          dialog.accept_async
        else
          dialog.dismiss
        end
      end

      class DialogAcceptor
        def initialize(dialog_type, options)
          @dialog_type = dialog_type
          @options = options
        end

        def handle(dialog)
          if @dialog_type == :prompt
            dialog.accept_async(promptText: @options[:with] || dialog.default_value)
          else
            dialog.accept_async
          end
        end
      end

      class DialogMessageMatcher
        def initialize(text_or_regex_or_nil)
          if [NilClass, Regexp, String].none? { |k| text_or_regex_or_nil.is_a?(k) }
            raise ArgumentError.new("invalid type: #{text_or_regex_or_nil.inspect}")
          end

          @filter = text_or_regex_or_nil
        end

        def matches?(message)
          case @filter
          when nil
            true
          when Regexp
            message =~ @filter
          when String
            message&.include?(@filter)
          end
        end
      end

      def capybara_accept_modal(dialog_type, **options, &block)
        timeout_sec = options[:wait]
        acceptor = DialogAcceptor.new(dialog_type, options)
        matcher = DialogMessageMatcher.new(options[:text])
        message_promise = Concurrent::Promises.resolvable_future
        handler = -> (dialog) {
          message = dialog.message
          if matcher.matches?(message)
            message_promise.fulfill(message)
            acceptor.handle(dialog)
          else
            message_promise.reject(Capybara::ModalNotFound.new("Dialog message=\"#{message}\" doesn't match"))
            dialog.dismiss
          end
        }
        capybara_dialog_event_handler.with_handler(handler) do
          block.call

          message = message_promise.value!(timeout_sec)
          if message_promise.fulfilled?
            message
          else
            # timed out
            raise Capybara::ModalNotFound
          end
        end
      end

      def capybara_dismiss_modal(dialog_type, **options, &block)
        timeout_sec = options[:wait]
        matcher = DialogMessageMatcher.new(options[:text])
        message_promise = Concurrent::Promises.resolvable_future
        handler = -> (dialog) {
          message = dialog.message
          if matcher.matches?(message)
            message_promise.fulfill(message)
          else
            message_promise.reject(Capybara::ModalNotFound.new("Dialog message=\"#{message}\" doesn't match"))
          end
          dialog.dismiss
        }
        capybara_dialog_event_handler.with_handler(handler) do
          block.call

          message = message_promise.value!(timeout_sec)
          if message_promise.fulfilled?
            message
          else
            # timed out
            raise Capybara::ModalNotFound
          end
        end
      end

      def capybara_set_last_response(response)
        @capybara_response_mutex.synchronize do
          @capybara_last_response = response
        end
      end

      class Headers < Hash
        def [](key)
          # Playwright accepts lower-cased keys.
          # However allow users to specify "Content-Type" or "User-Agent".
          super(key.downcase)
        end
      end

      def capybara_response_headers
        headers = @capybara_response_mutex.synchronize { @capybara_last_response&.headers || {} }

        Headers.new.tap do |h|
          headers.each do |key, value|
            h[key] = value
          end
        end
      end

      def capybara_status_code
        @capybara_response_mutex.synchronize { @capybara_last_response&.status.to_i }
      end

      def capybara_reset_frames
        @capybara_frames.clear
      end

      # @param frame [Playwright::Frame]
      def capybara_push_frame(frame)
        @capybara_frames << frame
      end

      def capybara_pop_frame
        @capybara_frames.pop
      end

      def capybara_current_frame
        @capybara_frames.last || main_frame
      end
    end
    ::Playwright::Page.prepend(PageExtension)
  end
end
