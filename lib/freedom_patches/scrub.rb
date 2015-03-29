class String
  # A poor man's scrub, Ruby 2.1 has a much better implementation, but this will do
  unless method_defined? :scrub
    def scrub(replace_char=nil)
      str = dup.force_encoding("utf-8")

      unless str.valid_encoding?
        # work around bust string with a double conversion
        str.encode!("utf-16","utf-8",:invalid => :replace)
        str.encode!("utf-8","utf-16")
      end

      str
    end
  end
end
