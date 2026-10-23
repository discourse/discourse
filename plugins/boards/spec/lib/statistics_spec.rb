# frozen_string_literal: true

RSpec.describe Boards::Statistics do
  fab!(:admin)
  fab!(:user_one, :user)
  fab!(:user_two, :user)
  fab!(:user_three, :user)

  let(:reference_time) { Time.zone.parse("2026-06-09 12:00:00") }

  before { enable_current_plugin }

  describe ".total_boards" do
    subject(:stats) { described_class.total_boards }

    before do
      freeze_time(reference_time) do
        Fabricate(:boards_board, name: "Total Boards Board", created_by: admin)
      end
    end

    it "returns the total number of boards" do
      freeze_time(reference_time) { expect(stats).to eq({ count: 1 }) }
    end
  end

  describe ".created_boards" do
    subject(:stats) { described_class.created_boards }

    before do
      freeze_time(reference_time) do
        Fabricate(
          :boards_board,
          name: "Recent Board",
          created_by: admin,
          created_at: reference_time - 6.hours,
        )
        Fabricate(
          :boards_board,
          name: "Week Board",
          created_by: admin,
          created_at: reference_time - 4.days,
        )
        Fabricate(
          :boards_board,
          name: "Month Board",
          created_by: admin,
          created_at: reference_time - 15.days,
        )
        Fabricate(
          :boards_board,
          name: "Previous Month Board",
          created_by: admin,
          created_at: reference_time - 45.days,
        )
        Fabricate(
          :boards_board,
          name: "Old Board",
          created_by: admin,
          created_at: reference_time - 70.days,
        )
      end
    end

    it "returns counts for each time bucket" do
      freeze_time(reference_time) do
        expect(stats).to eq({ last_day: 1, "7_days": 2, "30_days": 3, previous_30_days: 1 })
      end
    end
  end

  describe ".viewed_boards" do
    subject(:stats) { described_class.viewed_boards }

    fab!(:recent_board) { Fabricate(:boards_board, name: "Viewed Recent", created_by: admin) }
    fab!(:week_board) { Fabricate(:boards_board, name: "Viewed Week", created_by: admin) }
    fab!(:previous_month_board) do
      Fabricate(:boards_board, name: "Viewed Previous Month", created_by: admin)
    end

    before do
      freeze_time(reference_time) do
        Fabricate(
          :boards_board_history,
          board: recent_board,
          acting_user: user_one,
          action: :board_viewed,
          created_at: reference_time - 6.hours,
        )
        Fabricate(
          :boards_board_history,
          board: recent_board,
          acting_user: user_two,
          action: :board_viewed,
          created_at: reference_time - 3.days,
        )
        Fabricate(
          :boards_board_history,
          board: week_board,
          acting_user: user_two,
          action: :board_viewed,
          created_at: reference_time - 4.days,
        )
        Fabricate(
          :boards_board_history,
          board: previous_month_board,
          acting_user: user_three,
          action: :board_viewed,
          created_at: reference_time - 45.days,
        )
        Fabricate(
          :boards_board_history,
          board: recent_board,
          acting_user: user_one,
          action: :board_renamed,
          created_at: reference_time - 6.hours,
        )
      end
    end

    it "returns counts for each time bucket" do
      freeze_time(reference_time) do
        expect(stats).to eq(
          { last_day: 1, "7_days": 2, "30_days": 2, previous_30_days: 1, count: 3 },
        )
      end
    end
  end

  describe ".active_boards" do
    subject(:stats) { described_class.active_boards }

    fab!(:recent_board) { Fabricate(:boards_board, name: "Active Recent", created_by: admin) }
    fab!(:month_board) { Fabricate(:boards_board, name: "Active Month", created_by: admin) }
    fab!(:previous_month_board) do
      Fabricate(:boards_board, name: "Active Previous Month", created_by: admin)
    end
    fab!(:column) { Fabricate(:boards_column, board: recent_board) }
    fab!(:recent_card) { Fabricate(:boards_card, board: recent_board, column:) }
    fab!(:month_card) do
      Fabricate(
        :boards_card,
        board: month_board,
        column: Fabricate(:boards_column, board: month_board),
      )
    end
    fab!(:previous_month_card) do
      Fabricate(
        :boards_card,
        board: previous_month_board,
        column: Fabricate(:boards_column, board: previous_month_board),
      )
    end

    before do
      freeze_time(reference_time) do
        Fabricate(
          :boards_card_history,
          board: recent_board,
          card: recent_card,
          acting_user: user_one,
          action: :card_created,
          created_at: reference_time - 6.hours,
        )
        Fabricate(
          :boards_card_history,
          board: recent_board,
          card: recent_card,
          acting_user: user_one,
          action: :card_edited,
          created_at: reference_time - 4.days,
        )
        Fabricate(
          :boards_card_history,
          board: month_board,
          card: month_card,
          acting_user: user_two,
          action: :card_moved,
          created_at: reference_time - 15.days,
        )
        Fabricate(
          :boards_card_history,
          board: previous_month_board,
          card: previous_month_card,
          acting_user: user_three,
          action: :card_deleted,
          created_at: reference_time - 45.days,
        )
        Fabricate(
          :boards_board_history,
          board: recent_board,
          acting_user: user_one,
          action: :board_renamed,
          created_at: reference_time - 6.hours,
        )
      end
    end

    it "returns counts for each time bucket" do
      freeze_time(reference_time) do
        expect(stats).to eq(
          { last_day: 1, "7_days": 1, "30_days": 2, previous_30_days: 1, count: 3 },
        )
      end
    end
  end

  describe ".active_users" do
    subject(:stats) { described_class.active_users }

    fab!(:board) { Fabricate(:boards_board, name: "Active Users Board", created_by: admin) }
    fab!(:column) { Fabricate(:boards_column, board:) }
    fab!(:card) { Fabricate(:boards_card, board:, column:) }

    before do
      freeze_time(reference_time) do
        Fabricate(
          :boards_card_history,
          board:,
          card:,
          acting_user: user_one,
          action: :card_viewed,
          created_at: reference_time - 6.hours,
        )
        Fabricate(
          :boards_board_history,
          board:,
          acting_user: user_two,
          action: :board_viewed,
          created_at: reference_time - 4.days,
        )
        Fabricate(
          :boards_board_history,
          board:,
          acting_user: user_one,
          action: :board_viewed,
          created_at: reference_time - 15.days,
        )
        Fabricate(
          :boards_card_history,
          board:,
          card:,
          acting_user: user_three,
          action: :card_viewed,
          created_at: reference_time - 45.days,
        )
        Fabricate(
          :boards_card_history,
          board:,
          card:,
          acting_user: user_one,
          action: :card_created,
          created_at: reference_time - 6.hours,
        )
      end
    end

    it "returns counts for each time bucket" do
      freeze_time(reference_time) do
        expect(stats).to eq(
          { last_day: 1, "7_days": 2, "30_days": 2, previous_30_days: 1, count: 3 },
        )
      end
    end
  end

  describe ".participating_users" do
    subject(:stats) { described_class.participating_users }

    fab!(:board) { Fabricate(:boards_board, name: "Participating Users Board", created_by: admin) }
    fab!(:column) { Fabricate(:boards_column, board:) }
    fab!(:card) { Fabricate(:boards_card, board:, column:) }

    before do
      freeze_time(reference_time) do
        Fabricate(
          :boards_card_history,
          board:,
          card:,
          acting_user: user_one,
          action: :card_created,
          created_at: reference_time - 6.hours,
        )
        Fabricate(
          :boards_board_history,
          board:,
          acting_user: user_two,
          action: :board_created,
          created_at: reference_time - 4.days,
        )
        Fabricate(
          :boards_card_history,
          board:,
          card:,
          acting_user: user_one,
          action: :card_moved,
          created_at: reference_time - 15.days,
        )
        Fabricate(
          :boards_card_history,
          board:,
          card:,
          acting_user: user_three,
          action: :card_edited,
          created_at: reference_time - 45.days,
        )
        Fabricate(
          :boards_card_history,
          board:,
          card:,
          acting_user: user_one,
          action: :card_viewed,
          created_at: reference_time - 6.hours,
        )
      end
    end

    it "returns counts for each time bucket" do
      freeze_time(reference_time) do
        expect(stats).to eq(
          { last_day: 1, "7_days": 2, "30_days": 2, previous_30_days: 1, count: 3 },
        )
      end
    end
  end
end
