module ActiveSupport
  remove_const :Notifications
end

module ActiveSupport
  module Notifications
    # Instrumentors are stored in a thread local.
    class Instrumenter
      attr_reader :id

      def initialize(notifier)
        @id = unique_id
        @notifier = notifier
      end

      # Instrument the given block by measuring the time taken to execute it
      # and publish it. Notice that events get sent even if an error occurs
      # in the passed-in block
      def instrument(name, payload={})
        @notifier.start(name, @id, payload)
        begin
          yield
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          raise e
        ensure
          @notifier.finish(name, @id, payload)
        end
      end

      private
        def unique_id
          SecureRandom.hex(10)
        end
    end

    class Event
      attr_reader :name, :time, :end, :transaction_id, :payload, :duration

      def initialize(name, start, ending, transaction_id, payload)
        @name           = name
        @payload        = payload.dup
        @time           = start
        @transaction_id = transaction_id
        @end            = ending
        @duration       = 1000.0 * (@end - @time)
      end

      def parent_of?(event)
        start = (time - event.time) * 1000
        start <= 0 && (start + duration >= event.duration)
      end
    end
  end
end

module ActiveSupport
  module Notifications
    # This is a default queue implementation that ships with Notifications.
    # It just pushes events to all registered log subscribers.
    class Fanout
      def initialize
        @subscribers = []
        @listeners_for = {}
      end

      def subscribe(pattern = nil, block = Proc.new)
        subscriber = Subscribers.new pattern, block
        @subscribers << subscriber
        @listeners_for.clear
        subscriber
      end

      def unsubscribe(subscriber)
        @subscribers.reject! { |s| s.matches?(subscriber) }
        @listeners_for.clear
      end

      def start(name, id, payload)
        listeners_for(name).each { |s| s.start(name, id, payload) }
      end

      def finish(name, id, payload)
        listeners_for(name).each { |s| s.finish(name, id, payload) }
      end

      def publish(name, *args)
        listeners_for(name).each { |s| s.publish(name, *args) }
      end

      def listeners_for(name)
        @listeners_for[name] ||= @subscribers.select { |s| s.subscribed_to?(name) }
      end

      def listening?(name)
        listeners_for(name).any?
      end

      # This is a sync queue, so there is no waiting.
      def wait
      end

      module Subscribers # :nodoc:
        def self.new(pattern, listener)
          if listener.respond_to?(:call)
            subscriber = Timed.new pattern, listener
          else
            subscriber = Evented.new pattern, listener
          end

          unless pattern
            AllMessages.new(subscriber)
          else
            subscriber
          end
        end

        class Evented #:nodoc:
          def initialize(pattern, delegate)
            @pattern = pattern
            @delegate = delegate
          end

          def start(name, id, payload)
            @delegate.start name, id, payload
          end

          def finish(name, id, payload)
            @delegate.finish name, id, payload
          end

          def subscribed_to?(name)
            @pattern === name.to_s
          end

          def matches?(subscriber_or_name)
            self === subscriber_or_name ||
              @pattern && @pattern === subscriber_or_name
          end
        end

        class Timed < Evented
          def initialize(pattern, delegate)
            @timestack = Hash.new { |h,id|
              h[id] = Hash.new { |ids,name| ids[name] = [] }
            }
            super
          end

          def publish(name, *args)
            @delegate.call name, *args
          end

          def start(name, id, payload)
            @timestack[id][name].push Time.now
          end

          def finish(name, id, payload)
            started = @timestack[id][name].pop
            @delegate.call(name, started, Time.now, id, payload)
          end
        end

        class AllMessages # :nodoc:
          def initialize(delegate)
            @delegate = delegate
          end

          def start(name, id, payload)
            @delegate.start name, id, payload
          end

          def finish(name, id, payload)
            @delegate.finish name, id, payload
          end

          def publish(name, *args)
            @delegate.publish name, *args
          end

          def subscribed_to?(name)
            true
          end

          alias :matches? :===
        end
      end
    end
  end
end

module ActiveSupport
  # = Notifications
  #
  # <tt>ActiveSupport::Notifications</tt> provides an instrumentation API for Ruby.
  #
  # == Instrumenters
  #
  # To instrument an event you just need to do:
  #
  #   ActiveSupport::Notifications.instrument("render", extra: :information) do
  #     render text: "Foo"
  #   end
  #
  # That executes the block first and notifies all subscribers once done.
  #
  # In the example above "render" is the name of the event, and the rest is called
  # the _payload_. The payload is a mechanism that allows instrumenters to pass
  # extra information to subscribers. Payloads consist of a hash whose contents
  # are arbitrary and generally depend on the event.
  #
  # == Subscribers
  #
  # You can consume those events and the information they provide by registering
  # a subscriber. For instance, let's store all "render" events in an array:
  #
  #   events = []
  #
  #   ActiveSupport::Notifications.subscribe("render") do |*args|
  #     events << ActiveSupport::Notifications::Event.new(*args)
  #   end
  #
  # That code returns right away, you are just subscribing to "render" events.
  # The block will be called asynchronously whenever someone instruments "render":
  #
  #   ActiveSupport::Notifications.instrument("render", extra: :information) do
  #     render text: "Foo"
  #   end
  #
  #   event = events.first
  #   event.name      # => "render"
  #   event.duration  # => 10 (in milliseconds)
  #   event.payload   # => { extra: :information }
  #
  # The block in the <tt>subscribe</tt> call gets the name of the event, start
  # timestamp, end timestamp, a string with a unique identifier for that event
  # (something like "535801666f04d0298cd6"), and a hash with the payload, in
  # that order.
  #
  # If an exception happens during that particular instrumentation the payload will
  # have a key <tt>:exception</tt> with an array of two elements as value: a string with
  # the name of the exception class, and the exception message.
  #
  # As the previous example depicts, the class <tt>ActiveSupport::Notifications::Event</tt>
  # is able to take the arguments as they come and provide an object-oriented
  # interface to that data.
  #
  # It is also possible to pass an object as the second parameter passed to the
  # <tt>subscribe</tt> method instead of a block:
  #
  #   module ActionController
  #     class PageRequest
  #       def call(name, started, finished, unique_id, payload)
  #         Rails.logger.debug ["notification:", name, started, finished, unique_id, payload].join(" ")
  #       end
  #     end
  #   end
  #
  #   ActiveSupport::Notifications.subscribe('process_action.action_controller', ActionController::PageRequest.new)
  #
  # resulting in the following output within the logs including a hash with the payload:
  #
  #   notification: process_action.action_controller 2012-04-13 01:08:35 +0300 2012-04-13 01:08:35 +0300 af358ed7fab884532ec7 {
  #      :controller=>"Devise::SessionsController",
  #      :action=>"new",
  #      :params=>{"action"=>"new", "controller"=>"devise/sessions"},
  #      :format=>:html,
  #      :method=>"GET",
  #      :path=>"/login/sign_in",
  #      :status=>200,
  #      :view_runtime=>279.3080806732178,
  #      :db_runtime=>40.053
  #    }
  #
  # You can also subscribe to all events whose name matches a certain regexp:
  #
  #   ActiveSupport::Notifications.subscribe(/render/) do |*args|
  #     ...
  #   end
  #
  # and even pass no argument to <tt>subscribe</tt>, in which case you are subscribing
  # to all events.
  #
  # == Temporary Subscriptions
  #
  # Sometimes you do not want to subscribe to an event for the entire life of
  # the application. There are two ways to unsubscribe.
  #
  # WARNING: The instrumentation framework is designed for long-running subscribers,
  # use this feature sparingly because it wipes some internal caches and that has
  # a negative impact on performance.
  #
  # === Subscribe While a Block Runs
  #
  # You can subscribe to some event temporarily while some block runs. For
  # example, in
  #
  #   callback = lambda {|*args| ... }
  #   ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
  #     ...
  #   end
  #
  # the callback will be called for all "sql.active_record" events instrumented
  # during the execution of the block. The callback is unsubscribed automatically
  # after that.
  #
  # === Manual Unsubscription
  #
  # The +subscribe+ method returns a subscriber object:
  #
  #   subscriber = ActiveSupport::Notifications.subscribe("render") do |*args|
  #     ...
  #   end
  #
  # To prevent that block from being called anymore, just unsubscribe passing
  # that reference:
  #
  #   ActiveSupport::Notifications.unsubscribe(subscriber)
  #
  # == Default Queue
  #
  # Notifications ships with a queue implementation that consumes and publish events
  # to log subscribers in a thread. You can use any queue implementation you want.
  #
  module Notifications
    @instrumenters = Hash.new { |h,k| h[k] = notifier.listening?(k) }

    class << self
      attr_accessor :notifier

      def publish(name, *args)
        notifier.publish(name, *args)
      end

      def instrument(name, payload = {})
        if @instrumenters[name]
          instrumenter.instrument(name, payload) { yield payload if block_given? }
        else
          yield payload if block_given?
        end
      end

      def subscribe(*args, &block)
        notifier.subscribe(*args, &block).tap do
          @instrumenters.clear
        end
      end

      def subscribed(callback, *args, &block)
        subscriber = subscribe(*args, &callback)
        yield
      ensure
        unsubscribe(subscriber)
      end

      def unsubscribe(args)
        notifier.unsubscribe(args)
        @instrumenters.clear
      end

      def instrumenter
        Thread.current[:"instrumentation_#{notifier.object_id}"] ||= Instrumenter.new(notifier)
      end
    end

    self.notifier = Fanout.new
  end
end
