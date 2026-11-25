# frozen_string_literal: true

RSpec.describe DiscourseMcp::Tools do
  fab!(:admin)
  fab!(:user)

  around do |example|
    Dir.mktmpdir do |directory|
      @root = Pathname.new(directory)
      @root.join(".skills/example/references").mkpath
      @root.join("docs/developer-guides").mkpath
      @root.join(".skills/example/SKILL.md").write(<<~MARKDOWN)
        ---
        name: example
        description: Example authoring instructions
        ---
        # Example
        Read references/details.md.
      MARKDOWN
      @root.join(".skills/example/references/details.md").write(
        "First line\nSecond line\nThird line\n",
      )
      @root.join("docs/developer-guides/example.md").write("Developer guide\n")
      example.run
    end
  end

  before { Rails.stubs(:root).returns(@root) }

  def request_context(user)
    instance_double(
      DiscourseMcp::RequestContext,
      content_policy: DiscourseMcp::ContentPolicy.new([]),
      guardian: user.guardian,
    )
  end

  describe ".call" do
    it "lists skills with descriptions and reads linked references in pages" do
      result =
        DiscourseMcp::Tools::ListAuthoringGuides.call(
          arguments: {
          },
          request_context: request_context(admin),
        )
      expect(result.dig(:structuredContent, :skills)).to contain_exactly(
        {
          name: "example",
          description: "Example authoring instructions",
          path: ".skills/example/SKILL.md",
        },
      )

      result =
        DiscourseMcp::Tools::ReadAuthoringGuide.call(
          arguments: {
            "path" => ".skills/example/references/details.md",
            "max_lines" => 2,
          },
          request_context: request_context(admin),
        )
      expect(result[:structuredContent]).to include(
        content: "First line\nSecond line\n",
        total_lines: 3,
        next_line: 3,
      )

      result =
        DiscourseMcp::Tools::ReadAuthoringGuide.call(
          arguments: {
            "path" => ".skills/example/references/details.md",
            "start_line" => 3,
          },
          request_context: request_context(admin),
        )
      expect(result[:structuredContent]).to include(content: "Third line\n", next_line: nil)

      result =
        DiscourseMcp::Tools::ReadAuthoringGuide.call(
          arguments: {
            "path" => ".skills/example/../../docs/developer-guides/example.md",
          },
          request_context: request_context(admin),
        )
      expect(result.dig(:structuredContent, :content)).to eq("Developer guide\n")
    end

    it "discovers installed theme guides without relying on the tutorial directory number" do
      Rails.stubs(:root).returns(Pathname.new(__dir__).join("../../..").realpath)

      result =
        DiscourseMcp::Tools::ListAuthoringGuides.call(
          arguments: {
          },
          request_context: request_context(admin),
        )[
          :structuredContent
        ]

      expect(result[:theme_guides]).not_to be_empty
    end

    it "rejects paths outside the guide directories, symlinks, and oversized files" do
      @root.join("private.md").write("Private data")
      @root.join(".skills/example/references/private.md").make_symlink(@root.join("private.md"))
      @root.join(".skills/example/large.md").write(
        "x" * (DiscourseMcp::Tools::AuthoringGuideSupport::MAX_BYTES + 1),
      )
      paths = %w[
        private.md
        ../private.md
        /etc/passwd
        .skills/example/references/private.md
        .skills/example/large.md
      ]

      paths.each do |path|
        expect do
          DiscourseMcp::Tools::ReadAuthoringGuide.call(
            arguments: {
              "path" => path,
            },
            request_context: request_context(admin),
          )
        end.to raise_error(DiscourseMcp::ToolError)
      end
    end

    it "hides authoring tools when repository documentation is absent" do
      primitive = DiscourseMcp.registry.find(:tool, "discourse_list_authoring_guides")
      expect(primitive.required_scopes).to eq([DiscourseMcp::Scopes::REPOSITORY_READ])
      expect(primitive.available?).to eq(true)
      Dir.mktmpdir do |directory|
        Rails.stubs(:root).returns(Pathname.new(directory))
        expect(primitive.available?).to eq(false)
      end
    end

    it "lists readable guides when another skill has malformed or non-object metadata" do
      @root.join(".skills/malformed").mkpath
      @root.join(".skills/malformed/SKILL.md").write("---\nname: [\n---\nInstructions\n")
      @root.join(".skills/array").mkpath
      @root.join(".skills/array/SKILL.md").write("---\n- unexpected\n---\nInstructions\n")

      result =
        DiscourseMcp::Tools::ListAuthoringGuides.call(
          arguments: {
          },
          request_context: request_context(admin),
        )[
          :structuredContent
        ]

      expect(result[:skills]).to contain_exactly(
        include(name: "example", description: "Example authoring instructions"),
        include(name: "malformed", description: ""),
        include(name: "array", description: ""),
      )
    end

    it "skips unavailable skills without hiding readable guides" do
      @root.join("private.md").write("Private instructions")
      @root.join(".skills/private").mkpath
      @root.join(".skills/private/SKILL.md").make_symlink(@root.join("private.md"))

      result =
        DiscourseMcp::Tools::ListAuthoringGuides.call(
          arguments: {
          },
          request_context: request_context(admin),
        )[
          :structuredContent
        ]

      expect(result[:skills]).to contain_exactly(include(name: "example"))
    end

    it "requires administrator access for listing and reading" do
      expect do
        DiscourseMcp::Tools::ListAuthoringGuides.call(
          arguments: {
          },
          request_context: request_context(user),
        )
      end.to raise_error(Discourse::InvalidAccess)
      expect do
        DiscourseMcp::Tools::ReadAuthoringGuide.call(
          arguments: {
            "path" => ".skills/example/SKILL.md",
          },
          request_context: request_context(user),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end
  end
end
