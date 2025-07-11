# frozen_string_literal: true

module ::DiscourseDataExplorer
  class Parameter
    attr_accessor :identifier, :type, :default, :nullable

    def initialize(identifier, type, default, nullable, validate: true)
      unless identifier
        raise ValidationError.new("Parameter declaration error - identifier is missing")
      end

      raise ValidationError.new("Parameter declaration error - type is missing") unless type

      # process aliases
      type = type.to_sym

      type = Parameter.type_aliases[type] if Parameter.type_aliases[type]

      unless Parameter.types[type]
        raise ValidationError.new("Parameter declaration error - unknown type #{type}")
      end

      @identifier = identifier
      @type = type
      @default = default
      @nullable = nullable
      begin
        cast_to_ruby default if default.present? && validate
      rescue ValidationError
        raise ValidationError.new(
                "Parameter declaration error - the default value is not a valid #{type}",
              )
      end
    end

    def to_hash
      { identifier: @identifier, type: @type, default: @default, nullable: @nullable }
    end

    def self.types
      @types ||=
        Enum.new(
          # Normal types
          :int,
          :bigint,
          :boolean,
          :string,
          :date,
          :time,
          :datetime,
          :double,
          # Selection help
          :user_id,
          :post_id,
          :topic_id,
          :category_id,
          :group_id,
          :badge_id,
          # Arrays
          :int_list,
          :string_list,
          :user_list,
          :group_list,
        )
    end

    def self.type_aliases
      @type_aliases ||= { integer: :int, text: :string, timestamp: :datetime }
    end

    def self.create_from_sql(sql, opts = {})
      in_params = false
      ret_params = []
      sql.lines.find do |line|
        line.chomp!

        if in_params
          # -- (ident) :(ident) (= (ident))?

          if line =~ /^\s*--\s*([a-zA-Z_ ]+)\s*:([a-z_]+)\s*(?:=\s+(.*)\s*)?$/
            type = $1
            ident = $2
            default = $3
            nullable = false
            if type =~ /^(null)?(.*?)(null)?$/i
              nullable = true if $1 || $3
              type = $2
            end
            type = type.strip

            begin
              ret_params << Parameter.new(ident, type, default, nullable, validate: opts[:strict])
            rescue StandardError
              raise if opts[:strict]
            end

            false
          elsif line =~ /^\s+$/
            false
          else
            true
          end
        else
          in_params = true if line =~ /^\s*--\s*\[params\]\s*$/
          false
        end
      end
      ret_params
    end

    def cast_to_ruby(string)
      string = @default unless string

      if string.blank?
        if @nullable
          return nil
        else
          raise ValidationError.new("Missing parameter #{identifier} of type #{type}")
        end
      end
      return nil if string.downcase == "#null"

      value = nil

      case @type
      when :int
        invalid_format string, "Not an integer" unless string =~ /^-?\d+$/
        value = string.to_i
        invalid_format string, "Too large" unless Integer === value
      when :bigint
        invalid_format string, "Not an integer" unless string =~ /^-?\d+$/
        value = string.to_i
      when :boolean
        value = !!(string =~ /t|true|y|yes|1/i)
      when :string
        value = string
      when :time
        begin
          value = Time.parse string
        rescue ArgumentError => e
          invalid_format string, e.message
        end
      when :date
        begin
          value = Date.parse string
        rescue ArgumentError => e
          invalid_format string, e.message
        end
      when :datetime
        begin
          value = DateTime.parse string
        rescue ArgumentError => e
          invalid_format string, e.message
        end
      when :double
        if string.strip =~ /^-?\d*\.?\d+$/
          value = Float(string)
        elsif string =~ /^(-?)Inf(inity)?$/i
          if $1.present?
            value = -Float::INFINITY
          else
            value = Float::INFINITY
          end
        elsif string =~ /^(-?)NaN$/i
          if $1.present?
            value = -Float::NAN
          else
            value = Float::NAN
          end
        else
          invalid_format string
        end
      when :category_id
        if string =~ %r{(.*)/(.*)}
          parent_name = $1
          child_name = $2
          parent = Category.query_parent_category(parent_name)
          invalid_format string, "Could not find category named #{parent_name}" unless parent
          object = Category.query_category(child_name, parent)
          if object.blank?
            invalid_format string,
                           "Could not find subcategory of #{parent_name} named #{child_name}"
          end
        else
          object =
            Category.where(id: string.to_i).first || Category.where(slug: string).first ||
              Category.where(name: string).first
          invalid_format string, "Could not find category named #{string}" if object.blank?
        end

        value = object.id
      when :user_id, :post_id, :topic_id, :group_id, :badge_id
        if string.gsub(/[ _]/, "") =~ /^-?\d+$/
          klass_name = (/^(.*)_id$/.match(type.to_s)[1].classify.to_sym)
          begin
            finder =
              if type == :post_id || type == :topic_id
                Object.const_get(klass_name).with_deleted
              else
                Object.const_get(klass_name)
              end
            object = finder.find(string.gsub(/[ _]/, "").to_i)
            value = object.id
          rescue ActiveRecord::RecordNotFound
            invalid_format string, "The specified #{klass_name} was not found"
          end
        elsif type == :user_id
          object = User.find_by_username_or_email(string)
          invalid_format string, "The user named #{string} was not found" if object.blank?
          value = object.id
        elsif type == :post_id
          if string =~ %r{/t/[^/]+/(\d+)(\?u=.*)?$}
            object = Post.with_deleted.find_by(topic_id: $1, post_number: 1)
            invalid_format string, "The first post for topic:#{$1} was not found" if object.blank?
            value = object.id
          elsif string =~ %r{(\d+)/(\d+)(\?u=.*)?$}
            object = Post.with_deleted.find_by(topic_id: $1, post_number: $2)
            if object.blank?
              invalid_format string, "The post at topic:#{$1} post_number:#{$2} was not found"
            end
            value = object.id
          end
        elsif type == :topic_id
          if string =~ %r{/t/[^/]+/(\d+)}
            begin
              object = Topic.with_deleted.find($1)
              value = object.id
            rescue ActiveRecord::RecordNotFound
              invalid_format string, "The topic with id #{$1} was not found"
            end
          end
        elsif type == :group_id
          object = Group.where(name: string).first
          invalid_format string, "The group named #{string} was not found" if object.blank?
          value = object.id
        else
          invalid_format string
        end
      when :int_list
        value = string.split(",").map { |s| s.downcase == "#null" ? nil : s.to_i }
        invalid_format string, "can't be empty" if value.length == 0
      when :string_list
        value = string.split(",").map { |s| s.downcase == "#null" ? nil : s }
        invalid_format string, "can't be empty" if value.length == 0
      when :user_list
        value = string.split(",").map { |s| User.find_by_username_or_email(s).id }
        invalid_format string, "can't be empty" if value.length == 0
      when :group_list
        value = string.split(",").map { |s| Group.where(name: s).first.name }
        invalid_format string, "The group with id #{string} was not found" if value.length == 0
      else
        raise TypeError.new("unknown parameter type??? should not get here")
      end

      value
    end

    private

    def invalid_format(string, msg = nil)
      if msg
        raise ValidationError.new("'#{string}' is an invalid #{type} - #{msg}")
      else
        raise ValidationError.new("'#{string}' is an invalid value for #{type}")
      end
    end
  end
end
