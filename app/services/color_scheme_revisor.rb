class ColorSchemeRevisor

  def initialize(color_scheme, params={})
    @color_scheme = color_scheme
    @params = params
  end

  def self.revise(color_scheme, params)
    self.new(color_scheme, params).revise
  end

  def revise
    ColorScheme.transaction do

      @color_scheme.name    = @params[:name]    if @params.has_key?(:name)
      @color_scheme.base_scheme_id = @params[:base_scheme_id] if @params.has_key?(:base_scheme_id)
      has_colors = @params[:colors]

      if has_colors
        @params[:colors].each do |c|
          if existing = @color_scheme.colors_by_name[c[:name]]
            existing.update_attributes(c)
          else
            @color_scheme.color_scheme_colors << ColorSchemeColor.new(name: c[:name], hex: c[:hex])
          end
        end
        @color_scheme.clear_colors_cache
      end

      @color_scheme.save if has_colors || @color_scheme.name_changed? || @color_scheme.base_scheme_id_changed?
    end
    @color_scheme
  end

end
