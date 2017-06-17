# name: navigation
# about: Plugin to add a custom nav menu links
# version: 0.0.2
# authors: Vinoth Kannan (vinothkannan@vinkas.com)
# url: https://github.com/vinkas0/discourse-navigation

enabled_site_setting :navigation_enabled

register_asset 'stylesheets/navigation.scss', :admin

add_admin_route 'admin.navigation.title', 'navigation'

PLUGIN_NAME ||= "navigation".freeze
STORE_NAME ||= "menu_links".freeze

after_initialize do

  module ::Navigation
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Navigation
    end
  end

  class Navigation::MenuLink
    class << self

      def main
        mainLinks = Array.new
        result = PluginStore.get(PLUGIN_NAME, STORE_NAME)

        return "" if result.blank?

        result.each do |id, value|
          unless value['visible_main'].nil?
            if value['visible_main'].eql? "true"
              link = ['<a href="', value['url'], '">', value['name'], "</a>"].join("")
              mainLinks.push(link)
            end
          end
        end

        mainLinks.join("")
      end

      def add(user_id, name, icon, url, visible)
        ensureAdmin user_id

        # TODO add i18n string
        raise StandardError.new "menu_links.missing_name" if name.blank?
        raise StandardError.new "menu_links.missing_url" if url.blank?

        menu_links = PluginStore.get(PLUGIN_NAME, STORE_NAME)
        menu_links = Hash.new if menu_links == nil

        id = SecureRandom.hex(16)
        record = {id: id,
                  name: name,
                  icon: icon,
                  url: url,
                  visible_main: visible['main'],
                  visible_hamburger_general: visible['hamburger_general'],
                  visible_hamburger_footer: visible['hamburger_footer'],
                  visible_brand_general: visible['brand_general'],
                  visible_brand_icon: visible['brand_icon']}

        menu_links_array = Array.new
        menu_links.each do |id, value|
          menu_links_array.push(value)
        end
        max = menu_links_array.map { |d| d[:position] }.max
        record['position'] = (max || 0) + 1

        menu_links[id] = record
        PluginStore.set(PLUGIN_NAME, STORE_NAME, menu_links)

        record
      end

      def edit(user_id, id, name, icon, url, visible)
        ensureAdmin user_id

        raise StandardError.new "menu_links.missing_name" if name.blank?
        raise StandardError.new "menu_links.missing_url" if url.blank?

        menu_links = PluginStore.get(PLUGIN_NAME, STORE_NAME)
        menu_links = Hash.new if menu_links == nil

        record = menu_links[id]
        record['name'] = name
        record['icon'] = icon
        record['url'] = url
        record['visible_main'] = visible['main']
        record['visible_hamburger_general'] = visible['hamburger_general']
        record['visible_hamburger_footer'] = visible['hamburger_footer']
        record['visible_brand_general'] = visible['brand_general']
        record['visible_brand_icon'] = visible['brand_icon']

        menu_links[id] = record
        PluginStore.set(PLUGIN_NAME, STORE_NAME, menu_links)

        record
      end

      def move(user_id, id, position)
        ensureAdmin user_id

        raise StandardError.new "menu_links.missing_position" if position.blank?

        menu_links = PluginStore.get(PLUGIN_NAME, STORE_NAME)
        menu_links = Hash.new if menu_links == nil

        record = menu_links[id]
        record['position'] = position

        menu_links[id] = record
        PluginStore.set(PLUGIN_NAME, STORE_NAME, menu_links)

        record
      end

      def remove(user_id, id)
        ensureAdmin user_id

        menu_links = PluginStore.get(PLUGIN_NAME, STORE_NAME)
        menu_links.delete id
        PluginStore.set(PLUGIN_NAME, STORE_NAME, menu_links)
      end

      def all
        menu_links = Array.new
        result = PluginStore.get(PLUGIN_NAME, STORE_NAME)

        return menu_links if result.blank?

        result.each do |id, value|
          menu_links.push(value)
        end

        menu_links
      end

      def ensureAdmin (user_id)
        user = User.find_by(id: user_id)

        unless user.try(:admin?)
          raise StandardError.new "menu_links.must_be_admin"
        end
      end

    end
  end

  register_custom_html extraNavItem: Navigation::MenuLink.main

  require_dependency "application_controller"

  class Navigation::MenulinksController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def create
      field_params = params.require(:menu_link)
      name   = field_params[:name]
      icon = field_params[:icon]
      url = field_params[:url]
      visible = Hash.new
      visible['main'] = field_params[:visible_main]
      visible['hamburger_general'] = field_params[:visible_hamburger_general]
      visible['hamburger_footer'] = field_params[:visible_hamburger_footer]
      visible['brand_general'] = field_params[:visible_brand_general]
      visible['brand_icon'] = field_params[:visible_brand_icon]
      user_id   = current_user.id

      begin
        record = Navigation::MenuLink.add(user_id, name, icon, url, visible)
        render json: record
      rescue StandardError => e
        render_json_error e.message
      end
    end

    def remove
      id = params.require(:id)
      user_id  = current_user.id

      begin
        record = Navigation::MenuLink.remove(user_id, id)
        render json: record
      rescue StandardError => e
        render_json_error e.message
      end
    end

    def update
      id = params.require(:id)
      field_params = params.require(:menu_link)
      position = field_params[:position]
      user_id = current_user.id

      if position.nil?
        name = field_params[:name]
        icon = field_params[:icon]
        url = field_params[:url]
        visible = Hash.new
        visible['main'] = field_params[:visible_main]
        visible['hamburger_general'] = field_params[:visible_hamburger_general]
        visible['hamburger_footer'] = field_params[:visible_hamburger_footer]
        visible['brand_general'] = field_params[:visible_brand_general]
        visible['brand_icon'] = field_params[:visible_brand_icon]

        begin
          record = Navigation::MenuLink.edit(user_id, id, name, icon, url, visible)
          render json: record
        rescue StandardError => e
          render_json_error e.message
        end
      else
        begin
          record = Navigation::MenuLink.move(user_id, id, position)
          render json: record
        rescue StandardError => e
          render_json_error e.message
        end
      end
    end

    def index
      begin
        menu_links = Navigation::MenuLink.all()
        render json: {menu_links: menu_links}
      rescue StandardError => e
        render_json_error e.message
      end
    end

  end

  Navigation::Engine.routes.draw do
    get "/menu_links" => "menulinks#index"
    post "/menu_links" => "menulinks#create"
    delete "/menu_links/:id" => "menulinks#remove"
    put "/menu_links/:id" => "menulinks#update"
  end

  Discourse::Application.routes.append do
    get '/admin/plugins/navigation' => 'admin/plugins#index', constraints: StaffConstraint.new
    mount ::Navigation::Engine, at: "/"
  end

end
