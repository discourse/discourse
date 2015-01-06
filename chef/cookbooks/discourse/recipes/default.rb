execute "upgrade-rvm" do
  command "gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3"
  command "rvm get stable && rvm reload"
  action :nothing
end

execute "upgrade-ruby" do
  command "yes | rvm install ruby-2.1.5 --verify-downloads 1"
  action :nothing
end

execute "set-ruby" do
  command "rvm use ruby-2.1.5"
  user "vagrant"
  action :nothing
end

ruby_block "ruby-upgrade-message" do
  block do
    Chef::Log.info "Upgrading ruby. This will take a while."
  end
  notifies :run, "execute[upgrade-rvm]", :immediately
  notifies :run, "execute[upgrade-ruby]", :immediately
  notifies :run, "execute[set-ruby]", :immediately
  action :create
end
