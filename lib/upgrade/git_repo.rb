module Upgrade; end

# like Grit just very very minimal
class Upgrade::GitRepo
  attr_reader :path

  def initialize(path)
    @path = path
    @memoize = {}
  end

  def valid?
    File.directory?("#{path}/.git")
  end

  def latest_local_commit
    run "rev-parse --short HEAD"
  end

  def latest_origin_commit
    run "rev-parse --short #{tracking_branch}"
  end

  def latest_origin_commit_date
    commit_date(latest_origin_commit)
  end

  def latest_local_commit_date
    commit_date(latest_local_commit)
  end

  def commits_behind
    run("rev-list --count #{tracking_branch}..HEAD").to_i
  end

  def url
    url = run "config --get remote.origin.url"
    if url =~ /^git/
      # hack so it works with git urls
      url = "https://github.com/#{url.split(":")[1]}"
    end
  end

  protected

  def commit_date(commit)
    unix_timestamp = run('show -s --format="%ct" ' << commit).to_i
    Time.at(unix_timestamp).to_datetime
  end

  def tracking_branch
    run "for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD)"
  end

  def ensure_updated
    @updated ||= Thread.new do
                   # this is a very slow operation, make it async
                   `cd #{path} && git remote update`
                 end
  end

  def run(cmd)
    ensure_updated
    @memoize[cmd] ||= `cd #{path} && git #{cmd}`.strip
  rescue => e
    p e
  end

end
