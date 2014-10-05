# Just ignore included associations that are to be embedded in the root instead of
# throwing an exception in AMS 0.8.x.
#
# The 0.9.0 branch does exactly this, see:
# https://github.com/rails-api/active_model_serializers/issues/377
module ActiveModel
  class Serializer
    # This method is copied over verbatim from the AMS version, except for silently
    # ignoring associations that cannot be embedded without a root instead of
    # raising an exception.
    def include!(name, options={})
      unique_values =
        if hash = options[:hash]
          if @options[:hash] == hash
            @options[:unique_values] ||= {}
          else
            {}
          end
        else
          hash = @options[:hash]
          @options[:unique_values] ||= {}
        end

      node = options[:node] ||= @node
      value = options[:value]

      if options[:include] == nil
        if @options.key?(:include)
          options[:include] = @options[:include].include?(name)
        elsif @options.include?(:exclude)
          options[:include] = !@options[:exclude].include?(name)
        end
      end

      association_class =
        if klass = _associations[name]
          klass
        elsif value.respond_to?(:to_ary)
          Associations::HasMany
        else
          Associations::HasOne
        end

      association = association_class.new(name, self, options)

      if association.embed_ids?
        node[association.key] = association.serialize_ids

        if association.embed_in_root? && hash.nil?
          # Don't raise an error!
        elsif association.embed_in_root? && association.embeddable?
          merge_association hash, association.root, association.serializables, unique_values
        end
      elsif association.embed_objects?
        node[association.key] = association.serialize
      end
    end
  end
end
