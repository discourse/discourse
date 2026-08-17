# frozen_string_literal: true

RSpec.describe "libvips initializer" do
  let(:initializer) { Rails.root.join("config/initializers/003-vips.rb") }

  it "checks vips directly in a local environment" do
    Rails.stubs(env: ActiveSupport::EnvironmentInquirer.new("development"))
    Discourse::Utils.expects(:execute_command).with("vips", "--version").returns("vips-8.18.0")

    expect { load initializer }.not_to raise_error
  end

  it "raises installation guidance when vips is unavailable locally" do
    Rails.stubs(env: ActiveSupport::EnvironmentInquirer.new("development"))
    Discourse::Utils.stubs(:execute_command).with("vips", "--version").raises(Errno::ENOENT)

    expect { load initializer }.to raise_error(Discourse::Utils::CommandError, <<~TEXT.strip)
        vips --version

        Discourse requires the `vips` command for image processing, but it could not be run.

        Install libvips, then restart Discourse:
        https://www.libvips.org/install.html
      TEXT
  end

  it "does not check vips in production" do
    Rails.stubs(env: ActiveSupport::EnvironmentInquirer.new("production"))
    Discourse::Utils.expects(:execute_command).never

    expect { load initializer }.not_to raise_error
  end
end
