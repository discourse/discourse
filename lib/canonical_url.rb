# frozen_string_literal: true

module CanonicalURL
  module ControllerExtensions
    def canonical_url(url_for_options = {})
      case url_for_options
      when Hash
        @canonical_url = url_for(url_for_options)
      else
        @canonical_url = url_for_options
      end
    end
  end

  module Helpers
    def canonical_link_tag(url = nil)
      return '' unless url || @canonical_url
      tag('link', rel: 'canonical', href: url || @canonical_url || request.url)
    end
  end
end

# https://github.com/mbleigh/canonical-url/blob/master/lib/canonical_url.rb

# Copyright (c) 2009 Michael Bleigh and Intridea, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.#
