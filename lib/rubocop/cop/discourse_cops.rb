# frozen_string_literal: true

module RuboCop
  module Cop
    module DiscourseCops
      # Avoid using chdir - it is not thread safe.
      #
      # Instead, you may be able to use:
      # Discourse::Utils.execute_command(chdir: 'test') do |runner|
      #   runner.exec('pwd')
      # end
      #
      # @example
      #   # bad
      #   Dir.chdir('test')
      class NoChdir < Cop
        MSG = 'Chdir is not thread safe.'

        def_node_matcher :using_chdir?, <<-MATCHER
          (send (const nil? :Dir) :chdir ...)
        MATCHER

        def on_send(node)
          return unless using_chdir?(node)
          add_offense(node, message: MSG)
        end
      end
    end
  end
end
