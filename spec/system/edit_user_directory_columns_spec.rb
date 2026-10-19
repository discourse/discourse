# frozen_string_literal: true

describe "Edit user directory columns" do
  fab!(:admin)

  let(:columns_modal) { PageObjects::Modals::EditUserDirectoryColumns.new }

  before { sign_in(admin) }

  # TODO (ui-kit-reorderable-list-cleanup) drop the context once the change
  # ships and this is the only arm.
  context "when enable_new_reordering_controls is enabled" do
    before { SiteSetting.enable_new_reordering_controls = true }

    it "keeps a column where the admin moved it" do
      columns = DirectoryColumn.order(:position).to_a

      visit("/u")
      columns_modal.open
      expect(columns_modal).to have_columns_in_order(columns)

      columns_modal.move_to_top(columns.last)
      columns_modal.save
      expect(columns_modal).to be_closed

      columns_modal.open
      expect(columns_modal).to have_columns_in_order([columns.last, *columns[0...-1]])
    end
  end
end
