# frozen_string_literal: true

class ColorSchemeRevisor
  def initialize(color_scheme, params = {})
    @color_scheme = color_scheme
    @params = params
  end

  def self.revise(color_scheme, params, diverge_from_remote: false)
    self.new(color_scheme, params).revise(diverge_from_remote:)
  end

  def revise(diverge_from_remote: false)
    ColorScheme.transaction do
      @color_scheme.name = @params[:name] if @params.has_key?(:name)
      @color_scheme.user_selectable = @params[:user_selectable] if @params.has_key?(
        :user_selectable,
      )

      @color_scheme.base_scheme_id = @params[:base_scheme_id] if @params.has_key?(:base_scheme_id)
      has_colors = @params[:colors]

      @color_scheme.diverge_from_remote if diverge_from_remote

      if has_colors
        @params[:colors].each do |c|
          if existing = @color_scheme.colors_by_name[c[:name]]
            existing.update(c)
          else
            @color_scheme.color_scheme_colors << ColorSchemeColor.new(name: c[:name], hex: c[:hex])
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
