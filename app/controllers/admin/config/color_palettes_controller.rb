# frozen_string_literal: true

class Admin::Config::ColorPalettesController < Admin::AdminController
  def index
    palettes = ColorScheme.all.to_a
    palettes.unshift(ColorScheme.base)
    default_theme = Theme.find_default
    default_light_palette = default_theme&.color_scheme_id
    default_dark_palette = default_theme&.dark_color_scheme_id

    palettes.sort! do |a, b|
      # 1. Display active light
      if default_light_palette.blank? && (a.is_builtin_default || b.is_builtin_default)
        next a.is_builtin_default ? -1 : 1
      end
      if (default_light_palette == a.id && !a.is_builtin_default) ||
           (default_light_palette == b.id && !b.is_builtin_default)
        next default_light_palette == a.id ? -1 : 1
      end

      # 2. Display active dark
      if default_dark_palette.blank? && (a.is_builtin_default || b.is_builtin_default)
        next a.is_builtin_default ? -1 : 1
      end
      if (default_dark_palette == a.id && !a.is_builtin_default) ||
           (default_dark_palette == b.id && !b.is_builtin_default)
        next default_dark_palette == a.id ? -1 : 1
      end

      # 3. Sort by user selectable first
      next a.user_selectable ? -1 : 1 if a.user_selectable != b.user_selectable

      # 4. Sort custom palettes (no theme) before themed palettes
      a_is_custom = a.theme_id.blank? && !a.is_builtin_default
      b_is_custom = b.theme_id.blank? && !b.is_builtin_default
      next a_is_custom ? -1 : 1 if a_is_custom != b_is_custom

      # 5. Prioritize palettes from the current default theme
      a_is_from_default_theme = a.theme_id.present? && (a.theme_id == default_theme&.id)
      b_is_from_default_theme = b.theme_id.present? && (b.theme_id == default_theme&.id)
      next a_is_from_default_theme ? -1 : 1 if a_is_from_default_theme != b_is_from_default_theme

      # 6. Finally, sort alphabetically by name
      next (a.name&.downcase || "") <=> (b.name&.downcase || "")
    end

    palettes.unshift(*ColorScheme.base_color_schemes.reject(&:is_builtin_default))

    render json: {
             palettes: serialize_data(palettes, ColorSchemeSerializer, root: false),
             extras: {
               default_theme: serialize_data(default_theme, ThemeSerializer, root: false),
             },
           }
  end

  def show
    render_serialized(ColorScheme.find(params[:id]), ColorSchemeSerializer, root: false)
  end
end
