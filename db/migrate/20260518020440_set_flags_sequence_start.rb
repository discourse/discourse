# frozen_string_literal: true

class SetFlagsSequenceStart < ActiveRecord::Migration[8.0]
  CUSTOM_FLAG_SEQUENCE_START = 1001

  def up
    execute <<~SQL
      ALTER SEQUENCE public.flags_id_seq START WITH #{CUSTOM_FLAG_SEQUENCE_START};

      SELECT setval(
        'public.flags_id_seq',
        GREATEST(
          #{CUSTOM_FLAG_SEQUENCE_START - 1},
          COALESCE((SELECT MAX(id) FROM public.flags), 0),
          (SELECT last_value FROM public.flags_id_seq)
        ),
        true
      );
    SQL
  end

  def down
    execute "ALTER SEQUENCE public.flags_id_seq START WITH 1"
  end
end
