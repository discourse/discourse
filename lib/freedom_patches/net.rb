if Gem::Version.new(RUBY_VERSION) == Gem::Version.new("2.5.1")
  require 'net/pop'

  module Net
    class POP3
      def inspect
        +"#<#{self.class} #{@address}:#{@port} open=#{@started}>"
      end
    end

    class POPMail
      def inspect
        +"#<#{self.class} #{@number}#{@deleted ? ' deleted' : ''}>"
      end

      def pop(dest = +'', &block) # :yield: message_chunk
        if block_given?
          @command.retr(@number, &block)
          nil
        else
          @command.retr(@number) do |chunk|
            dest << chunk
          end
          dest
        end
      end

      def top(lines, dest = +'')
        @command.top(@number, lines) do |chunk|
          dest << chunk
        end
        dest
      end

      def header(dest = +'')
        top(0, dest)
      end
    end

    class POP3Command
      def inspect
        +"#<#{self.class} socket=#{@socket}>"
      end
    end
  end
elsif Gem::Version.new(RUBY_VERSION) > Gem::Version.new("2.5.1")
  # See https://github.com/ruby/ruby/commit/7830a950efa6d312e7c662beabaa0f8d7b4e0a23
  STDERR.puts 'This monkey patch is no longer required.'
end
