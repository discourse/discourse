# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBadgesGroupings < PageObjects::Pages::Base
      def add_grouping(name)
        within(modal) do
          find(".badge-groupings__add-grouping").click
          find(".badge-grouping-name-input").fill_in(with: name)
        end

        save

        self
      end

      def save
        page.find(".badge-groupings__save").click
        expect(self).to be_closed
        self
      end

      def modal
        page.find(".badge-groupings-modal")
      end

      def closed?
        page.has_no_css?(".badge-groupings-modal")
      end
    end
  end
end
