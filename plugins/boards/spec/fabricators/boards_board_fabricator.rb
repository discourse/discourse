# frozen_string_literal: true

Fabricator(:boards_board, class_name: "Boards::Board") do
  name { sequence(:boards_board_name) { |i| "#{Faker::Company.buzzword.capitalize} Board #{i}" } }
  created_by { Fabricate(:user) }
  transient :column_names
  transient :additional_manage_groups

  after_create do |board, evaluator|
    (evaluator[:column_names] || []).each_with_index do |column_name, index|
      board.columns.create!(title: column_name, position: index)
    end

    additional_manage_groups =
      Array
        .wrap(evaluator[:additional_manage_groups])
        .map { |group| AccessControlList.flat_acl_for(group, "manage") }

    AccessControlList.bulk_insert_flattened_acl!(
      AccessControlList.inject_mandatory_acl(additional_manage_groups, board),
      board,
      Boards::PLUGIN_NAME,
    )
  end
end
