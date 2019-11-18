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

        def_node_matcher :using_dir_chdir?, <<-MATCHER
          (send (const nil? :Dir) :chdir ...)
        MATCHER

        def_node_matcher :using_fileutils_cd?, <<-MATCHER
          (send (const nil? :FileUtils) :cd ...)
        MATCHER

        def on_send(node)
          return if !(using_dir_chdir?(node) || using_fileutils_cd?(node))
          add_offense(node, message: MSG)
        end
      end
    end
  end
end
