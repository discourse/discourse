old_pkgs =
  if(::File.exist?(node[:omnibus_updater][:cache_dir]))
    Dir.glob(File.join(node[:omnibus_updater][:cache_dir], 'chef*')).find_all do |file|
      !file.include?(node[:omnibus_updater][:version].to_s) && !file.scan(/\.(rpm|deb)$/).empty?
    end
  else
    []
  end

old_pkgs.each do |filename|
  file filename do
    action :delete
  end
end
