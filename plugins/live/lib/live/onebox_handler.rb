# frozen_string_literal: true

module Live
  class OneboxHandler
    TEMPLATE_PATH = File.expand_path("../onebox/templates/live_room.mustache", __dir__)
    private_constant :TEMPLATE_PATH

    def self.handle(url, route)
      return unless room = oneboxable_room(route)

      args = {
        url: url,
        name: room.name,
        icon: room.stage? ? "podcast" : "microphone-lines",
        room_type_label: I18n.t("live.onebox.room_type.#{room.room_type_name}"),
        description:
          if room.cooked_description.present?
            PrettyText.excerpt(room.cooked_description, SiteSetting.post_onebox_maxlength)
          end,
      }

      Mustache.render(template, args)
    end

    # Oneboxes are cached and baked into cooked posts that anyone may read,
    # so a room only previews when an anonymous visitor could see it.
    def self.oneboxable_room(route)
      return if route[:slug].blank?

      room = Live::Room.find_by(slug: route[:slug])
      return if room.blank? || room.ephemeral?
      return unless Guardian.new.can_see_live_room?(room)

      room
    end

    def self.template
      return File.read(TEMPLATE_PATH) if Rails.env.development?

      @template ||= File.read(TEMPLATE_PATH)
    end
    private_class_method :template
  end
end
