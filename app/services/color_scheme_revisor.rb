# frozen_string_literal: true

class ColorSchemeRevisor
  def initialize(color_scheme, params = {})
    @color_scheme = color_scheme
    @params = params
  end

  def self.revise(color_scheme, params)
    self.new(color_scheme, params).revise
  end

  def self.revise_existing_colors_only(color_scheme, params)
    self.new(color_scheme, params).revise(update_existing_colors_only: true)
  end

  def revise(update_existing_colors_only: false)
    ColorScheme.transaction do
      @color_scheme.name = @params[:name] if @params.has_key?(:name)
      @color_scheme.user_selectable = @params[:user_selectable] if @params.has_key?(
        :user_selectable,
      )
      @color_scheme.base_scheme_id = @params[:base_scheme_id] if @params.has_key?(:base_scheme_id)
      has_colors = @params[:colors]

      if has_colors
        @params[:colors].each do |c|
          if existing = @color_scheme.colors_by_name[c[:name]]
            existing.update(c)
          elsif !update_existing_colors_only
            @color_scheme.color_scheme_colors << ColorSchemeColor.new(
              name: c[:name],
              hex: c[:hex],
              dark_hex: c[:dark_hex],
            )
          end
        end
        @color_scheme.clear_colors_cache
      end

      if has_colors || @color_scheme.will_save_change_to_name? ||
           @color_scheme.will_save_change_to_user_selectable? ||
           @color_scheme.will_save_change_to_base_scheme_id?
        @color_scheme.save
      end
    end
    @color_scheme
  end
end
