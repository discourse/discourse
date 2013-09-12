unless rails4?
  module HTML
    class WhiteListSanitizer
        # Sanitizes a block of css code. Used by #sanitize when it comes across a style attribute
      def sanitize_css(style)
        # disallow urls
        style = style.to_s.gsub(/url\s*\(\s*[^\s)]+?\s*\)\s*/, ' ')

        # gauntlet
        if style !~ /\A([:,;#%.\sa-zA-Z0-9!]|\w-\w|\'[\s\w]+\'|\"[\s\w]+\"|\([\d,\s]+\))*\z/ ||
            style !~ /\A(\s*[-\w]+\s*:\s*[^:;]*(;|$)\s*)*\z/
          return ''
        end

        clean = []
        style.scan(/([-\w]+)\s*:\s*([^:;]*)/) do |prop,val|
          if allowed_css_properties.include?(prop.downcase)
            clean <<  prop + ': ' + val + ';'
          elsif shorthand_css_properties.include?(prop.split('-')[0].downcase)
            unless val.split().any? do |keyword|
              !allowed_css_keywords.include?(keyword) &&
                keyword !~ /\A(#[0-9a-f]+|rgb\(\d+%?,\d*%?,?\d*%?\)?|\d{0,2}\.?\d{0,2}(cm|em|ex|in|mm|pc|pt|px|%|,|\))?)\z/
            end
              clean << prop + ': ' + val + ';'
            end
          end
        end
        clean.join(' ')
      end
    end
  end

  module HTML
    class WhiteListSanitizer
      self.protocol_separator = /:|(&#0*58)|(&#x70)|(&#x0*3a)|(%|&#37;)3A/i

      def contains_bad_protocols?(attr_name, value)
        uri_attributes.include?(attr_name) &&
        (value =~ /(^[^\/:]*):|(&#0*58)|(&#x70)|(&#x0*3a)|(%|&#37;)3A/i && !allowed_protocols.include?(value.split(protocol_separator).first.downcase.strip))
      end
    end
  end

  module ActiveRecord
    class Relation

      def where_values_hash
        equalities = with_default_scope.where_values.grep(Arel::Nodes::Equality).find_all { |node|
          node.left.relation.name == table_name
        }

        Hash[equalities.map { |where| [where.left.name, where.right] }].with_indifferent_access
      end

    end
  end

  module ActiveRecord
    class PredicateBuilder # :nodoc:
      def self.build_from_hash(engine, attributes, default_table, allow_table_name = true)
        predicates = attributes.map do |column, value|
          table = default_table

          if allow_table_name && value.is_a?(Hash)
            table = Arel::Table.new(column, engine)

            if value.empty?
              '1 = 2'
            else
              build_from_hash(engine, value, table, false)
            end
          else
            column = column.to_s

            if allow_table_name && column.include?('.')
              table_name, column = column.split('.', 2)
              table = Arel::Table.new(table_name, engine)
            end

            attribute = table[column]

            case value
            when ActiveRecord::Relation
              value = value.select(value.klass.arel_table[value.klass.primary_key]) if value.select_values.empty?
              attribute.in(value.arel.ast)
            when Array, ActiveRecord::Associations::CollectionProxy
              values = value.to_a.map {|x| x.is_a?(ActiveRecord::Base) ? x.id : x}
              ranges, values = values.partition {|v| v.is_a?(Range) || v.is_a?(Arel::Relation)}

              array_predicates = ranges.map {|range| attribute.in(range)}

              if values.include?(nil)
                values = values.compact
                if values.empty?
                  array_predicates << attribute.eq(nil)
                else
                  array_predicates << attribute.in(values.compact).or(attribute.eq(nil))
                end
              else
                array_predicates << attribute.in(values)
              end

              array_predicates.inject {|composite, predicate| composite.or(predicate)}
            when Range, Arel::Relation
              attribute.in(value)
            when ActiveRecord::Base
              attribute.eq(value.id)
            when Class
              # FIXME: I think we need to deprecate this behavior
              attribute.eq(value.name)
            when Integer, ActiveSupport::Duration
              # Arel treats integers as literals, but they should be quoted when compared with strings
              column = engine.connection.schema_cache.columns_hash[table.name][attribute.name.to_s]
              attribute.eq(Arel::Nodes::SqlLiteral.new(engine.connection.quote(value, column)))
            else
              attribute.eq(value)
            end
          end
        end

        predicates.flatten
      end
    end
  end
end
