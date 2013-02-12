gem_package 'chef' do
  action :purge
  only_if do
    Chef::Provider::Package::Rubygems.new(
      Chef::Resource::GemPackage.new('dummy_package')
    ).gem_env.gem_paths.detect{|path|
      path.start_with?('/opt/omnibus') || path.start_with?('/opt/chef')
    }.nil? && node[:omnibus_updater][:remove_chef_system_gem]
  end
end
