require 'discourse_plugin'

module DiscourseMathjax

  class Plugin < DiscoursePlugin

    def setup
      # Add our Assets
      register_js('http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML')
    end

  end
end
