name 'phantomjs'
maintainer 'CustomInk'
maintainer_email 'webops@customink.com'
license 'Apache 2.0'
description 'Installs/Configures phantomjs'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.0.10'

recipe 'phantomjs::default', 'Install phantomjs binary'

%w(amazon centos debian fedora oracle rhel scientific ubuntu).each do |os|
  supports os
end

attribute 'version',
  :display_name => 'Version',
  :description => 'The Version of phantomjs to install',
  :default => '1.7.0'
