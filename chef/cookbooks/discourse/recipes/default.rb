# Upgrade ruby. I don't know chef, so this is probably more complicated than it needs to be:
# execute "upgrade-rvm" do
#   command "rvm get stable && rvm reload"
#   action :nothing
# end

# execute "upgrade-ruby" do
#   command "yes | rvm install 2.0.0-p247-turbo"
#   action :nothing
# end



# TODO: set-default-ruby SUCCEEDS BY DOES NOTHING. HOW TO GET THIS TO WORK??

# execute "set-default-ruby" do
#   command "rvm --default use ruby-2.0.0-p247-turbo"
#   user "vagrant"
#   action :nothing
# end




# execute "install-gems" do
#   command "gem install bundler && bundle install"
#   user "vagrant"
#   cwd "/vagrant"
#   action :nothing
# end

# ruby_block "ruby-upgrade-message" do
#   block do
#     Chef::Log.info "Upgrading ruby. This will take a while."
#   end
#   only_if { `ruby -v`.include?('2.0.0p0') }
#   notifies :run, "execute[upgrade-rvm]", :immediately
#   notifies :run, "execute[upgrade-ruby]", :immediately
#   notifies :run, "execute[set-default-ruby]", :immediately
#   notifies :run, "execute[install-gems]", :immediately
#   action :create
# end
