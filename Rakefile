# encoding: utf-8

require 'rubygems'
require 'rake'
require 'rake/clean'
$:.unshift 'lib'
begin
  gem 'rubygems-tasks', '~> 0.2'
  require 'rubygems/tasks'

  Gem::Tasks.new
rescue LoadError => e
  warn e.message
  warn "Run `gem install rubygems-tasks` to install Gem::Tasks."
end

begin
  gem 'rdoc', '~> 3.0'
  require 'rdoc/task'

  RDoc::Task.new do |rdoc|
    rdoc.title = "spectator-emacs"
  end
rescue LoadError => e
  warn e.message
  warn "Run `gem install rdoc` to install 'rdoc/task'."
end
task :doc => :rdoc

begin
  gem 'rspec', '~> 2.4'
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new
rescue LoadError => e
  task :spec do
    abort "Please run `gem install rspec` to install RSpec."
  end
end

task :test    => :spec
task :default => :spec

desc "Run spectator-emacs"
task :spectator_emacs do
  load "bin/spectator-emacs"
end
