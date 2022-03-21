# frozen_string_literal: true

SanePatch.patch("seed-fu", "~> 2.3.9") do
  module FreedomPatches
    module SeedFu
      def update_id_sequence
        max_seeded_id = @data.filter_map { |d| d["id"] }.max
        seq = @model_class.connection.execute(<<~SQL)
        SELECT last_value
        FROM #{@model_class.sequence_name}
        SQL
        last_seq_value = seq.first["last_value"]

        if max_seeded_id && last_seq_value < max_seeded_id
          # Update the sequence to start from the highest existing id
          @model_class.connection.reset_pk_sequence!(@model_class.table_name)
        else
          # The sequence is already higher than any of our seeded ids - better not touch it
        end
      end

      ::SeedFu::Seeder.prepend(self)
    end
  end
end
