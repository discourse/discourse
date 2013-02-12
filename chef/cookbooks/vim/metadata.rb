maintainer       "Opscode, Inc."
maintainer_email "cookbooks@opscode.com"
license          "Apache 2.0"
description      "Installs vim and optional extra packages."
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.0.2"

%w{debian ubuntu arch redhat centos fedora scientific}.each do |os|
  supports os
end

