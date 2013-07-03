require 'discourse_plugin'

module DiscourseMathjax

  class Plugin < DiscoursePlugin

    def setup
		# Add our Assets
	  register_js('discourse_mathjax')
    end

  end
end
