# spectator-emacs

* [Homepage](https://github.com/laynor/spectator-emacs#readme)
* [Issues](https://github.com/laynor/spectator-emacs/issues)
* [Documentation](http://rubydoc.info/gems/spectator-emacs/frames)
* Email [mailto:laynor at gmail.com]

## Description

`spectator-emacs` is a [Spectator][spectator]
extension that provides discreet notificatoins in the Emacs modeline,
via the [Enotify][enotify] Emacs notification
system.

The RSpec output is displayed in an emacs buffer, and using the
[RSpec Org Formatter][RSpecOrgFormatter],
they are nicely formatted as an org-mode file. Minimize your switching
from Emacs to the shell or the browser to just display the test
results!

If you hate growl-style popups and prefer a simple green/red
(customizable!) indicator on the modeline, spectator-emacs is for you.

## Features

* Notifications on the emacs modeline
* Short summary report on mouse-over in the modeline indicator
* Easily switch to the results buffer with just a click on the
  modeline indicator
* Org formatted RSpec results with the aid of RSpec Org Formatter
* Summary extraction can be customized to work with different RSpec
  output formats
* all the features offered by Spectator

## Install
```
$ gem install spectator-emacs
```
## Examples

To run `spectator-emacs`, just run it!
```
$ spectator-emacs
```
To customize it, create a .spectator-emacs file in your project root.
You can customize various aspects of how spectator-emacs works:

* Enotify host (default: localhost)
* Enotify port (default: 5000)
* The notification message that will appear on the emacs modeline
  (default: 'F' for failures, 'P' for pending, 'S' for success)
* The notification faces used to display the icons in the modeline
  (default: `enotify-success-face` for success,
  `enotify-failure-face`for failures, `enotify-warning-face` for
  success with pending examples)
* The Enotify slot id to register for notifications

An example `.spectator-emacs' file:


```ruby
require 'spectator/emacs'

@runner = Spectator::ERunner.new(:enotify_port => 5001,
                                 :notification_messages => {
                                   :failure => "failure",
                                   :success => "success",
                                   :pending => "pending"
                                 },
                                 :slot_id => "project foobar"
                                 :notification_face => {
                                   :pending => :font_lock_warning_face,
                                   # see the docs for detail on Symbol#keyword
                                   :success => :success.keyword,
                                   :failure => :failure
                                 }) do |runner|
  # This code will be executed before entering the main loop.

  def format_summary(examples, failures, pending)
    summary = "#{examples} examples"
    summary << ", #{failures} failures"  if failures > 0
    summary << ", #{pending} pending"  if pending > 0
    summary << "."
    summary
  end

  # The default summary extraction method works with
  # the standard documentation formatter, or any formatter
  # that puts the summary on the last line and with the
  # same format of the documentation formatter.
  # It uses the helper function
  # Spectator::Spec#extract_rspec_stats, which can be
  # useful if the summary is expressed with the same
  # pattern but on a line other than the last.
  # For example, the RSpecOrgFormatter puts the summary on
  # the 6th-last line.
  #
  def extract_rspec_org_summary(output)
    runner.extract_rspec_stats(output, -6)
  end

  # Suppose rspec is using a custom formatter that
  # puts the summary in a format in the last lines
  # with a format like the following:
  #
  #   Examples: 123
  #   Errors: 12
  #   Pending: 2
  #
  def runner.extract_rspec_summary(output)
    summary_lines = summary[-3..-1]
    examples = summary[-3].split(':')[1].to_i
    errors = summary[-2].split(':')[1].to_i
    pending = summary[-1].split(':')[1].to_i
    stats = {
      :examples => examples,
      :failures => failures,
      :pending => pending,
      :summary => format_summary(examples, failures, pending)
    }
    stats.merge(:status => rspec_status(stats))
    stats
  end
end
```



## Requirements

`spectator-emacs` requires a working Emacs installation. You need to
install [Enotify][enotify], which can be found in the [MELPA][melpa]
repository.

You also need to load the `enotify-spectator-emacs` Enotify plugin.

Put this in your .emacs:

```lisp
(require 'enotify)
(enotify-minor-mode t)
(add-to-list 'load-path "path/to/enotify-spectator-emacs")
(require 'enotify-spectator-emacs)
```

## Copyright

Copyright (c) 2013 Alessandro Piras

See LICENSE.txt for details.

[enotify]:http://github.com/laynor/enotify
[spectator]:http://github.com/elia/spectator
[RSpecOrgFormatter]:http://github.org/laynor/rspec_org_formatter
[melpa]:http://melpa.milkbox.net/
