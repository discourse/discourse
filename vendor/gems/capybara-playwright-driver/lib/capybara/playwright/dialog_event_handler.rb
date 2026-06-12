require 'securerandom'

module Capybara
  module Playwright
    # LILO event handler
    class DialogEventHandler
      class Item
        def initialize(dialog_proc)
          @id = SecureRandom.uuid
          @proc = dialog_proc
        end

        attr_reader :id

        def call(dialog)
          @proc.call(dialog)
        end
      end

      def initialize
        @handlers = []
        @mutex = Mutex.new
      end

      attr_writer :default_handler

      def add_handler(callable)
        item = Item.new(callable)
        @mutex.synchronize {
          @handlers << item
        }
        item.id
      end

      def remove_handler(id)
        @mutex.synchronize {
          @handlers.reject! { |item| item.id == id }
        }
      end

      def with_handler(callable, &block)
        id = add_handler(callable)
        begin
          block.call
        ensure
          remove_handler(id)
        end
      end

      def handle_dialog(dialog)
        handler = @mutex.synchronize {
          @handlers.pop || @default_handler
        }
        handler&.call(dialog)
      end
    end
  end
end
