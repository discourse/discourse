# frozen_string_literal: true

RSpec.describe DiscourseMcp::Tools do
  fab!(:admin)
  fab!(:user)

  around do |example|
    Dir.mktmpdir do |directory|
      @root = Pathname.new(directory)
      @root.join("app").mkpath
      @root.join("config").mkpath
      @root.join("app/example.rb").write("class Example\n  ORIGINAL = true\nend\n")
      @root.join("config/database.yml").write("PRIVATE_CONFIGURATION\n")
      @root.join("app/link.rb").make_symlink(@root.join("config/database.yml"))
      git("init", "-q")
      git("add", ".")
      commit
      @revision = git("rev-parse", "HEAD").strip
      example.run
    end
  end

  before do
    Rails.stubs(:root).returns(@root)
    Discourse.stubs(:git_version).returns(@revision)
  end

  def git(*arguments)
    output, errors, status = Open3.capture3("git", "-C", @root.to_s, *arguments)
    raise errors unless status.success?
    output
  end

  def commit
    git(
      "-c",
      "user.name=Source tests",
      "-c",
      "user.email=source@example.com",
      "-c",
      "commit.gpgsign=false",
      "commit",
      "-qm",
      "Source snapshot",
    )
  end

  def request_context(actor = admin)
    instance_double(
      DiscourseMcp::RequestContext,
      content_policy: DiscourseMcp::ContentPolicy.new([]),
      guardian: actor.guardian,
    )
  end

  describe ".call" do
    it "caches checkout availability per root and requires a separate scope" do
      primitive = DiscourseMcp.registry.find(:tool, "discourse_read_source")
      expect(primitive.required_scopes).to eq([DiscourseMcp::Scopes::REPOSITORY_READ])
      expect(primitive.available?).to eq(true)
      FileUtils.rm_rf(@root.join(".git"))
      expect(primitive.available?).to eq(true)
      Dir.mktmpdir do |directory|
        Rails.stubs(:root).returns(Pathname.new(directory))
        expect(primitive.available?).to eq(false)
      end
    end

    it "recovers availability after a temporary Git failure" do
      primitive = DiscourseMcp.registry.find(:tool, "discourse_read_source")
      config = @root.join(".git/config")
      original = config.read
      config.write("invalid configuration\n")
      expect(primitive.available?).to eq(false)

      config.write(original)
      expect(primitive.available?).to eq(true)
    end

    it "pins reads to the reported revision while labelling local working-tree changes" do
      @root.join("app/example.rb").write("class Example\n  NEW_COMMIT = true\nend\n")
      git("add", ".")
      commit
      @root.join("app/example.rb").write("class Example\n  LOCAL_EDIT = true\nend\n")

      result =
        DiscourseMcp::Tools::ReadSource.call(
          arguments: {
            "path" => "app/example.rb",
            "start_line" => 2,
            "max_lines" => 1,
          },
          request_context: request_context,
        )[
          :structuredContent
        ]
      expect(result).to include(content: "  ORIGINAL = true\n", next_line: 3)
      expect(result[:source]).to include(
        source_revision: @revision,
        working_tree_changed: true,
        runtime_snapshot_verified: false,
      )
      expect(result[:public_url]).to eq(
        "https://github.com/discourse/discourse/blob/#{@revision}/app/example.rb#L2",
      )

      result =
        DiscourseMcp::Tools::ReadSource.call(
          arguments: {
            "path" => "app/example.rb",
            "mode" => "working_tree",
          },
          request_context: request_context,
        )[
          :structuredContent
        ]
      expect(result).to include(mode: "working_tree", public_url: nil)
      expect(result[:content]).to include("LOCAL_EDIT")
    end

    it "searches literal text in the selected revision with bounded line references" do
      @root.join("app/example.rb").write("LOCAL_EDIT\nLOCAL_EDIT\n")
      committed =
        DiscourseMcp::Tools::SearchSource.call(
          arguments: {
            "query" => "ORIGINAL",
          },
          request_context: request_context,
        )[
          :structuredContent
        ]
      expect(committed[:matches]).to contain_exactly(
        include(path: "app/example.rb", line: 2, content: "  ORIGINAL = true"),
      )

      working =
        DiscourseMcp::Tools::SearchSource.call(
          arguments: {
            "query" => "LOCAL_EDIT",
            "mode" => "working_tree",
            "max_results" => 1,
          },
          request_context: request_context,
        )[
          :structuredContent
        ]
      expect(working[:matches]).to contain_exactly(
        include(path: "app/example.rb", line: 1, public_url: nil),
      )
      expect(working[:truncated]).to eq(true)
    end

    it "rejects private paths, untracked files and symbolic links in either mode" do
      @root.join("app/untracked.rb").write("UNTRACKED\n")
      paths = %w[/etc/passwd ../app/example.rb config/database.yml app/link.rb app/untracked.rb]
      paths << "app/invalid\0.rb"
      %w[committed working_tree].each do |mode|
        paths.each do |path|
          expect do
            DiscourseMcp::Tools::ReadSource.call(
              arguments: {
                "path" => path,
                "mode" => mode,
              },
              request_context: request_context,
            )
          end.to raise_error(DiscourseMcp::ToolError)
        end
      end
    end

    it "returns more than three matches from a file and reports the result limit" do
      @root.join("app/example.rb").write("REPEATED_MATCH\n" * 5)
      git("add", ".")
      commit
      Discourse.stubs(:git_version).returns(git("rev-parse", "HEAD").strip)

      result =
        DiscourseMcp::Tools::SearchSource.call(
          arguments: {
            "query" => "REPEATED_MATCH",
            "max_results" => 4,
          },
          request_context: request_context,
        )[
          :structuredContent
        ]

      expect(result[:matches].pluck(:line)).to eq([1, 2, 3, 4])
      expect(result[:truncated]).to eq(true)
    end

    it "pages locale files larger than the search output limit in either mode" do
      @root.join("config/locales").mkpath
      @root.join("config/locales/server.en.yml").write("translation: example\n" * 30_000)
      git("add", ".")
      commit
      Discourse.stubs(:git_version).returns(git("rev-parse", "HEAD").strip)

      %w[committed working_tree].each do |mode|
        result =
          DiscourseMcp::Tools::ReadSource.call(
            arguments: {
              "path" => "config/locales/server.en.yml",
              "mode" => mode,
              "start_line" => 20_000,
              "max_lines" => 2,
            },
            request_context: request_context,
          )[
            :structuredContent
          ]

        expect(result).to include(
          content: "translation: example\n" * 2,
          total_lines: 30_000,
          next_line: 20_002,
        )
      end
    end

    it "keeps page output bounded even when a file is within the read limit" do
      @root.join("app/long.rb").write("x" * (DiscourseMcp::Tools::SourceSupport::MAX_BYTES + 1))
      git("add", ".")
      commit
      Discourse.stubs(:git_version).returns(git("rev-parse", "HEAD").strip)

      expect do
        DiscourseMcp::Tools::ReadSource.call(
          arguments: {
            "path" => "app/long.rb",
            "max_lines" => 1,
          },
          request_context: request_context,
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.source_too_large"))
    end

    it "rejects untracked filenames containing pathspec wildcards" do
      @root.join("app/*.rb").write("Untracked local data\n")

      expect do
        DiscourseMcp::Tools::ReadSource.call(
          arguments: {
            "path" => "app/*.rb",
            "mode" => "working_tree",
          },
          request_context: request_context,
        )
      end.to raise_error(DiscourseMcp::ToolError)
    end

    it "rejects private paths before checking the checkout" do
      FileUtils.rm_rf(@root.join(".git"))

      expect do
        DiscourseMcp::Tools::ReadSource.call(
          arguments: {
            "path" => "config/database.yml",
          },
          request_context: request_context,
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.source_path_unavailable"))
    end

    it "cleans up subprocess readers when Git times out" do
      @root.join("bin").mkpath
      @root.join("bin/git").write("#!/bin/sh\nexec /bin/sleep 30\n")
      @root.join("bin/git").chmod(0o755)
      original_path = ENV["PATH"]
      ENV["PATH"] = "#{@root.join("bin")}:#{original_path}"
      threads = []
      trace = TracePoint.new(:thread_begin) { threads << Thread.current }

      trace.enable(target_thread: nil) do
        stub_const(DiscourseMcp::Tools::SourceSupport, :COMMAND_TIMEOUT_SECONDS, 0.1) do
          expect do
            expect do
              DiscourseMcp::Tools::SourceVersion.call(
                arguments: {
                },
                request_context: request_context,
              )
            end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.source_unavailable"))
          end.not_to output.to_stderr
        end
      end
      readers =
        threads.select { |thread| %w[mcp-source-stdout mcp-source-stderr].include?(thread.name) }
      expect(readers.map(&:alive?)).to eq([false, false])
    ensure
      ENV["PATH"] = original_path
    end

    it "excludes unsupported extensions before applying the search output budget" do
      @root.join("app/aaa.txt").write("SUPPORTED_MATCH\n" * 30_000)
      @root.join("app/example.rb").write("SUPPORTED_MATCH\n")
      git("add", ".")
      commit
      Discourse.stubs(:git_version).returns(git("rev-parse", "HEAD").strip)

      %w[committed working_tree].each do |mode|
        result =
          DiscourseMcp::Tools::SearchSource.call(
            arguments: {
              "query" => "SUPPORTED_MATCH",
              "mode" => mode,
            },
            request_context: request_context,
          )[
            :structuredContent
          ]

        expect(result[:matches]).to contain_exactly(include(path: "app/example.rb", line: 1))
        expect(result[:truncated]).to eq(false)
      end
    end

    it "reports a checkout fallback explicitly and refuses a missing reported commit" do
      Discourse.stubs(:git_version).returns("unknown")
      result =
        DiscourseMcp::Tools::SourceVersion.call(arguments: {}, request_context: request_context)
      expect(result[:structuredContent][:source]).to include(
        source_revision: @revision,
        revision_basis: "checkout_head_fallback",
      )

      Discourse.stubs(:git_version).returns("0" * 40)
      expect do
        DiscourseMcp::Tools::SourceVersion.call(arguments: {}, request_context: request_context)
      end.to raise_error(DiscourseMcp::ToolError)
    end

    it "bounds oversized source reads and search output" do
      @root.join("app/large.rb").write(
        "BOUNDED_MATCH\n" * (DiscourseMcp::Tools::SourceSupport::MAX_FILE_BYTES / 14 + 1),
      )
      git("add", ".")
      commit
      Discourse.stubs(:git_version).returns(git("rev-parse", "HEAD").strip)

      %w[committed working_tree].each do |mode|
        expect do
          DiscourseMcp::Tools::ReadSource.call(
            arguments: {
              "path" => "app/large.rb",
              "mode" => mode,
            },
            request_context: request_context,
          )
        end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.source_too_large"))
      end

      result =
        DiscourseMcp::Tools::SearchSource.call(
          arguments: {
            "query" => "BOUNDED_MATCH",
            "max_results" => 5,
          },
          request_context: request_context,
        )[
          :structuredContent
        ]
      expect(result[:matches].size).to eq(5)
      expect(result[:truncated]).to eq(true)
    end

    it "requires administrator access" do
      [
        DiscourseMcp::Tools::SourceVersion,
        DiscourseMcp::Tools::SearchSource,
        DiscourseMcp::Tools::ReadSource,
      ].each do |tool|
        expect { tool.call(arguments: {}, request_context: request_context(user)) }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
    end
  end
end
