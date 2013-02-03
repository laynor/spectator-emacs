# -*- encoding: utf-8 -*-

require File.expand_path('../lib/spectator/emacs/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "spectator-emacs"
  gem.version       = Spectator::Emacs::VERSION
  gem.summary       = %q{A Spectator monkey-patch that displays notifications on the emacs modeline.}
  gem.description   = <<-DESCRIPTION
  spectator-emacs is a Spectator extension that provides discreet
  notificatoins in the Emacs modeline, via the Enotify Emacs
  notification system.

  == Features ==
  * Notifications on the emacs modeline
  * Short summary report on mouse-over in the modeline indicator
  * Easily switch to the results buffer with just a click on the
    modeline indicator
  * Org formatted RSpec results with the aid of RSpec Org Formatter
  * Summary extraction can be customized to work with different RSpec
    output formats
  * all the features offered by Spectator
  DESCRIPTION
  gem.license       = "MIT"
  gem.authors       = ["Alessandro Piras"]
  gem.email         = "laynor@gmail.com"
  gem.homepage      = "https://github.com/laynor/spectator-emacs#readme"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_development_dependency 'rdoc', '~> 3.0'
  gem.add_development_dependency 'rspec', '~> 2.4'
  gem.add_development_dependency 'rubygems-tasks', '~> 0.2'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'redcarpet'
  gem.add_dependency 'rspec'
  gem.add_dependency 'spectator', '~> 1.2'
  gem.add_dependency 'open4'
  gem.add_dependency 'rb-inotify', '~> 0.8.8'
  gem.add_dependency 'docopt'
end
