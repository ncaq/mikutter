alias __source_distinct__ source
def source(url)
  @loaded ||= {}
  unless @loaded[url]
    @loaded[url] = true
    __source_distinct__(url) end end

source 'https://rubygems.org'

ruby '>= 2.7.0'

group :default do
  gem 'addressable','>= 2.8.0', '< 2.9'
  gem 'delayer','>= 1.2.1', '< 2.0'
  gem 'delayer-deferred','>= 2.2.0', '< 3.0'
  gem 'diva','>= 2.0.1', '< 3.0'
  gem 'memoist','>= 0.16.2', '< 0.17'
  gem 'oauth','>= 0.5.8'
  gem 'pluggaloid','>= 1.7.0', '< 2.0'
  gem 'typed-array','>= 0.1.2', '< 0.2'
end

group :test do
  gem 'test-unit','>= 3.5.2', '< 4.0'
  gem 'rake','>= 13.0.6'
  gem 'mocha','>= 1.13.0'
  gem 'ruby-prof','>= 1.4.3'
end


group :plugin do
  Dir.glob(File.expand_path(File.join(__dir__, 'plugin/*/Gemfile'))){ |path|
    eval File.open(path).read
  }
  Dir.glob(File.join(File.expand_path(ENV['MIKUTTER_CONFROOT'] || '~/.mikutter'), 'plugin/*/Gemfile')){ |path|
    eval File.open(path).read, binding, path
  }
end
