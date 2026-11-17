# frozen_string_literal: true

RSpec.describe DiscourseVips::WorkerProcess do
  describe ".shared_socket_path" do
    let(:checkout_name) { "worktree-#{SecureRandom.hex(4)}" }
    let(:deep_parent) { "/home/dev/#{"nested/" * 12}" }

    around do |example|
      described_class.instance_variable_set(:@shared_socket_path, nil)
      example.run
    ensure
      described_class.instance_variable_set(:@shared_socket_path, nil)
      Dir.glob("/tmp/discourse-vips-#{checkout_name}*").each { |dir| FileUtils.rm_rf(dir) }
    end

    # Each process resolves the path on its own, so clear the memoized value to
    # resolve it the way a freshly forked process would.
    def resolve_for(root)
      Rails.stubs(:root).returns(Pathname.new(root))
      described_class.instance_variable_set(:@shared_socket_path, nil)
      described_class.shared_socket_path
    end

    it "keeps the socket inside the app root when the path fits" do
      expect(resolve_for("/srv/#{checkout_name}")).to eq(
        "/srv/#{checkout_name}/tmp/discourse-vips-worker/test/socket",
      )
    end

    it "moves the socket to /tmp under the checkout name when the app root is too deep" do
      root = "#{deep_parent}#{checkout_name}"

      path = resolve_for(root)

      expect(path).to eq("/tmp/discourse-vips-#{checkout_name}/test/socket")
      expect(resolve_for(root)).to eq(path)
    end

    it "truncates a long checkout name to fit the socket path limit" do
      long_name = "#{checkout_name}-#{"x" * 150}"

      path = resolve_for("#{deep_parent}#{long_name}")

      expect(path.bytesize).to be <= 103
      expect(path).to start_with("/tmp/discourse-vips-#{checkout_name}-xxx")
      expect(path).to end_with("/test/socket")
    end

    it "adds a numeric suffix when another checkout already uses the same name" do
      first_root = "#{deep_parent}first/#{checkout_name}"
      second_root = "#{deep_parent}second/#{checkout_name}"

      first_path = resolve_for(first_root)
      second_path = resolve_for(second_root)

      expect(first_path).to eq("/tmp/discourse-vips-#{checkout_name}/test/socket")
      expect(second_path).to match(%r{\A/tmp/discourse-vips-#{checkout_name}-\d{3}/test/socket\z})
      expect([resolve_for(first_root), resolve_for(second_root)]).to eq([first_path, second_path])
    end

    it "adds a numeric suffix when a same-named directory belongs to another user" do
      root = "#{deep_parent}#{checkout_name}"
      FileUtils.mkdir_p("/tmp/discourse-vips-#{checkout_name}")
      File.write("/tmp/discourse-vips-#{checkout_name}/app-root", root)
      File::Stat.any_instance.stubs(:owned?).returns(false)

      expect(resolve_for(root)).to match(
        %r{\A/tmp/discourse-vips-#{checkout_name}-\d{3}/test/socket\z},
      )
    end
  end
end
