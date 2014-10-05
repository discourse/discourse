class ColorSchemeRevisor

  def initialize(color_scheme, params={})
    @color_scheme = color_scheme
    @params = params
  end

  def self.revise(color_scheme, params)
    self.new(color_scheme, params).revise
  end

  def self.revert(color_scheme)
    self.new(color_scheme).revert
  end

  def revise
    ColorScheme.transaction do
      if @params[:enabled]
        ColorScheme.where('id != ?', @color_scheme.id).update_all enabled: false
      end

      @color_scheme.name    = @params[:name]    if @params.has_key?(:name)
      @color_scheme.enabled = @params[:enabled] if @params.has_key?(:enabled)
      new_version = false

      if @params[:colors]
        new_version = @params[:colors].any? do |c|
          (existing = @color_scheme.colors_by_name[c[:name]]).nil? or existing.hex != c[:hex]
        end
      end

      if new_version
        old_version = ColorScheme.create(
          name: @color_scheme.name,
          enabled: false,
          colors: @color_scheme.colors_hashes,
          versioned_id: @color_scheme.id,
          version: @color_scheme.version)
        @color_scheme.version += 1
      end

      if @params[:colors]
        @params[:colors].each do |c|
          if existing = @color_scheme.colors_by_name[c[:name]]
            existing.update_attributes(c)
          end
        end
      end

      @color_scheme.save
      @color_scheme.clear_colors_cache
    end
    @color_scheme
  end

  def revert
    ColorScheme.transaction do
      if prev = @color_scheme.previous_version
        @color_scheme.version = prev.version
        @color_scheme.colors.clear
        prev.colors.update_all(color_scheme_id: @color_scheme.id)
        prev.destroy
        @color_scheme.save!
        @color_scheme.clear_colors_cache
      end
    end

    @color_scheme
  end

end
