# frozen_string_literal: true

module Boards
  class BoardsController < BaseController
    def respond
      render body: nil
    end
  end
end
