# frozen_string_literal: true

RSpec.describe GitUrl do
  it "handles the discourse github repo by ssh" do
    expect(GitUrl.normalize("git@github.com:discourse/discourse.git")).to eq(
      "ssh://git@github.com/discourse/discourse.git",
    )
  end

  it "handles the discourse github repo by https" do
    expect(GitUrl.normalize("https://github.com/discourse/discourse.git")).to eq(
      "https://github.com/discourse/discourse.git",
    )
  end

  it "adds .git and strips a trailing slash for a GitHub URL without .git" do
    expect(GitUrl.normalize("https://github.com/discourse/discourse")).to eq(
      "https://github.com/discourse/discourse.git",
    )
    expect(GitUrl.normalize("https://github.com/discourse/discourse/")).to eq(
      "https://github.com/discourse/discourse.git",
    )
  end

  it "applies the same .git normalization to non-GitHub https git hosts" do
    expect(GitUrl.normalize("https://gitlab.com/user/component")).to eq(
      "https://gitlab.com/user/component.git",
    )
    expect(GitUrl.normalize("https://gitlab.com/user/component/")).to eq(
      "https://gitlab.com/user/component.git",
    )
  end

  it "does not double up .git for a non-GitHub URL that already has it" do
    expect(GitUrl.normalize("https://gitlab.com/user/component.git")).to eq(
      "https://gitlab.com/user/component.git",
    )
  end

  it "normalizes equivalent non-GitHub URL variants to the same string" do
    variants = %w[
      https://gitlab.com/user/component
      https://gitlab.com/user/component/
      https://gitlab.com/user/component.git
    ]
    expect(variants.map { |v| GitUrl.normalize(v) }.uniq.size).to eq(1)
  end
end
