# frozen_string_literal: true

module ::Boards
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Boards
    config.autoload_paths << File.join(config.root, "lib")
  end

  class << self
    def card_onebox_template
      path = Rails.root.join("plugins/boards/lib/onebox/templates/boards_card.mustache")
      return File.read(path) if Rails.env.development?

      @card_onebox_template ||= File.read(path)
    end

    def board_onebox_template
      path = Rails.root.join("plugins/boards/lib/onebox/templates/boards_board.mustache")
      return File.read(path) if Rails.env.development?

      @board_onebox_template ||= File.read(path)
    end
  end
end
