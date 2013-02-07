# encoding: utf-8

# Generates a slug. This is annoying beacuse it's duplicating what the javascript 
# does, but on the other hand slugs are never matched so it's okay if they differ
# a little.
module Slug

  def self.for(string)

    str = string.dup
    str.strip!
    str.downcase!

    from = "àáäâèéëêìíïîòóöôùúüûñç·/_,:;."
    to   = "aaaaeeeeiiiioooouuuunc\-"

    str.tr!(from, to)

    str.gsub!(/[^a-z0-9 -]/, '')
    str.gsub!(/\s+/, '-')
    str.gsub!(/\-+/, '-')

    str
  end

end
