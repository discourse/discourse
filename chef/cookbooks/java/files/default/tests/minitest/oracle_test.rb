require 'minitest/spec'
require 'open3'

describe_recipe 'java::oracle' do


  include MiniTest::Chef::Assertions
  include MiniTest::Chef::Context
  include MiniTest::Chef::Resources

  it "installs the correct version of the jdk" do
    stdin,stdout,stderr = Open3.popen3( "java -version" )
    version_line = stderr.readline
    jdk_version = version_line.scan(/\.([678])\./)[0][0]
    assert_equal node['java']['jdk_version'], jdk_version
  end

  it "properly sets JAVA_HOME environment variable" do
    stdin,stdout,stderr = Open3.popen3( "echo $JAVA_HOME" )
    java_home = stdout.readline.rstrip
    assert_equal node['java']['java_home'], java_home 
  end

end
