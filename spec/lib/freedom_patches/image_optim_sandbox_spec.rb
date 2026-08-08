# frozen_string_literal: true

RSpec.describe "image_optim Landlock sandbox freedom patch" do
  def landlock?
    Discourse::SafeExec.landlock_supported?
  end

  it "routes worker commands through Discourse::SafeExec with the network denied" do
    Discourse::SafeExec
      .expects(:capture)
      .with { |*_command, **opts| opts[:seccomp_deny_network] == true }
      .returns("")

    expect(ImageOptim::Cmd.run({ "PATH" => ENV["PATH"] }, "true")).to eq(true)
  end

  it "returns false (keep original) when the sandboxed command fails" do
    Discourse::SafeExec.expects(:capture).raises(
      Discourse::Utils::CommandError.new("boom", stdout: "", stderr: "", status: nil),
    )

    expect(ImageOptim::Cmd.run({}, "false")).to eq(false)
  end

  it "allows reading a file passed in argv" do
    skip("Landlock unsupported on this host") unless landlock?

    Dir.mktmpdir do |dir|
      file = File.join(dir, "data")
      File.write(file, "hello")
      expect(ImageOptim::Cmd.run({ "PATH" => ENV["PATH"] }, "cat", file)).to eq(true)
    end
  end

  it "denies reading a file outside the allowlist" do
    skip("Landlock unsupported on this host") unless landlock?

    Dir.mktmpdir do |dir|
      secret = File.join(dir, "secret")
      File.write(secret, "top secret")
      # secret is referenced only inside a shell string, so its directory is
      # never granted and the sandbox must block the read.
      expect(ImageOptim::Cmd.run({ "PATH" => ENV["PATH"] }, "sh", "-c", "cat #{secret}")).to eq(
        false,
      )
    end
  end

  it "still optimizes a real image through the sandbox" do
    skip("Landlock unsupported on this host") unless landlock?

    Dir.mktmpdir do |dir|
      png = File.join(dir, "logo.png")
      FileUtils.cp(Rails.root.join("spec/fixtures/images/logo.png"), png)
      before = File.size(png)

      FileHelper.optimize_image!(png)

      expect(File.size(png)).to be <= before
      expect(FastImage.type(png)).to eq(:png)
    end
  end
end
