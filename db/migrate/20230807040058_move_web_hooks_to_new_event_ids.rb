# frozen_string_literal: true

class MoveWebHooksToNewEventIds < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 101, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 1;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 102, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 1;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 103, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 1;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 104, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 1;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 105, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 1;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 201, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 2;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 202, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 2;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 203, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 2;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 204, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 2;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 301, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 302, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 303, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 304, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 305, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 306, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 307, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 308, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 309, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 3;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 401, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 4;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 402, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 4;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 403, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 4;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 501, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 5;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 502, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 5;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 503, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 5;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 601, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 6;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 602, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 6;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 603, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 6;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 901, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 9;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 902, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 9;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1001, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 10;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1101, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 11;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1102, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 11;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1201, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 12;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1202, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 12;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1301, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 13;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1302, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 13;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1401, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 14;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1402, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 14;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1501, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 15;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1601, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 16;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1701, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 17;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1702, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 17;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1801, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 18;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1802, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 18;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1803, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 18;

      INSERT INTO web_hook_event_types_hooks(web_hook_event_type_id, web_hook_id)
      SELECT 1804, web_hook_id FROM web_hook_event_types_hooks WHERE web_hook_event_types_hooks.web_hook_event_type_id = 18;

      DELETE FROM web_hook_event_types WHERE id < 100;
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM web_hook_event_types_hooks WHERE web_hook_event_type_id > 100
    SQL
  end
end
