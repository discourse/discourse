module OmnibusChecker
  def is_omnibus?
    Gem.bindir =~ %r{/opt/(opscode|chef)/}
  end
end

OmnibusChecker.send(:extend, OmnibusChecker)

unless(Chef::Recipe.instance_methods.include?(:is_omnibus?))
  Chef::Recipe.send(:include, OmnibusChecker)
end
