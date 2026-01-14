# frozen_string_literal: true

module PageObjects
  module Modals
    class AdminSearch < PageObjects::Modals::Base
      MODAL_SELECTOR = ".admin-search-modal"

      def search(query)
        find(".admin-search__input-field").fill_in(with: query)
      end

      def find_result(type, position)
        all(".admin-search__result[data-result-type='#{type}']")[position]
      end

      def input_enter
        find(".admin-search__input-field").send_keys(:enter)
      end
    end
  end
end
