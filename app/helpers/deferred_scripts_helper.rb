module DeferredScriptsHelper

  # Provides a javascript map of the files in the 'defer' directory
  def deferred_scripts
    files = {}

    Dir.glob("#{Rails.root}/app/assets/javascripts/defer/*.js").each do |file|
      module_name = "defer/#{File.basename(file, '.js')}"
      file_name = asset_path("defer/#{File.basename(file)}")
      files[module_name] = file_name
    end

    return files.to_json.html_safe
  end

end
