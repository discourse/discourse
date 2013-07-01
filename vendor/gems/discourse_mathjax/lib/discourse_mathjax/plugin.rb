require 'discourse_plugin'

module DiscourseMathjax

  class Plugin < DiscoursePlugin

    def setup
		# Add our Assets
	  register_js('discourse_mathjax',
                    server_side: File.expand_path('../../../vendor/assets/javascripts/discourse_mathjax.js', __FILE__))
    end

  end
end
