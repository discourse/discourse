# perf fixes, review for each rails upgrade.

# we call this a lot
class ActiveRecord::Base
  def present?
    true
  end
  def blank?
    false
  end
end

class ActionView::Helpers::AssetTagHelper::AssetIncludeTag
private

  # pluralization is fairly expensive, and pluralizing the word javascript 400 times is pointless

  def path_to_asset(source, options = {})
    asset_paths.compute_public_path(source, pluralize_asset_name(asset_name), options.merge(:ext => extension))
  end


  def path_to_asset_source(source)
    asset_paths.compute_source_path(source, pluralize_asset_name(asset_name), extension)
  end


  def pluralize_asset_name(asset_name)
    @@pluralization_cache ||= {}
    plural = @@pluralization_cache[asset_name] ||= asset_name.to_s.pluralize
  end


end

